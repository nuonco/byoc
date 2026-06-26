#!/usr/bin/env bash

set -e
set -o pipefail
set -u

# Empties and deletes the s3_buckets component's buckets via the AWS API, then
# schedules its KMS key for deletion. Deliberately decoupled from the Terraform
# teardown: aws_s3_bucket has lifecycle.prevent_destroy and is a
# block-destructive-changes critical resource, so deleting it must be an explicit
# operator action, not a side effect of a plan.
#
# IRREVERSIBLE: S3 has no snapshot. Versioned buckets have every object version
# and delete-marker purged before the bucket is removed.
#
# Required env (set in the action from the s3_buckets component outputs):
#   BLOB_BUCKET        blob bucket name (blob_bucket.id output)
#   CLICKHOUSE_BUCKET  clickhouse bucket name (clickhouse_bucket.id output)
#   TEMPLATES_BUCKET   install-templates bucket name (install_template_bucket.id output)
# Optional env:
#   KMS_PENDING_WINDOW_DAYS  KMS deletion window (default 7, AWS minimum)

export AWS_PAGER=""

: "${BLOB_BUCKET:?BLOB_BUCKET is required}"
: "${CLICKHOUSE_BUCKET:?CLICKHOUSE_BUCKET is required}"
: "${TEMPLATES_BUCKET:?TEMPLATES_BUCKET is required}"
kms_window="${KMS_PENDING_WINDOW_DAYS:-7}"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to enumerate object versions." >&2
  exit 1
fi

echo "==================================================================="
echo " S3 delete: blob, clickhouse, install-templates"
echo "==================================================================="

empty_and_delete_bucket() {
  local b="$1"
  if [ -z "$b" ] || [ "$b" = "null" ]; then
    echo "  (empty bucket name, skipping)"
    return 0
  fi

  if ! aws s3api head-bucket --bucket "$b" >/dev/null 2>&1; then
    echo "  bucket ${b} not found (already deleted) — skipping"
    return 0
  fi

  echo "  emptying ${b} (objects, versions, delete-markers)..."
  while :; do
    local page del n
    page=$(aws s3api list-object-versions --bucket "$b" --max-items 1000 --output json)
    del=$(printf '%s' "$page" | jq -c '{Objects: ([(.Versions // []), (.DeleteMarkers // [])] | add | map({Key, VersionId})), Quiet: true}')
    n=$(printf '%s' "$del" | jq '.Objects | length')
    [ "${n:-0}" -eq 0 ] && break
    aws s3api delete-objects --bucket "$b" --delete "$del" >/dev/null
    echo "    purged ${n} object versions"
  done

  echo "  deleting bucket ${b}..."
  aws s3api delete-bucket --bucket "$b"
  echo "  deleted ${b}"
}

for b in "$BLOB_BUCKET" "$CLICKHOUSE_BUCKET" "$TEMPLATES_BUCKET"; do
  echo ""
  echo "Bucket: ${b}"
  empty_and_delete_bucket "$b"
done

# ── schedule the clickhouse bucket KMS key for deletion ──────────────────────
# The key is aliased alias/bucket-key-<clickhouse-bucket-name>.
kms_alias="alias/bucket-key-${CLICKHOUSE_BUCKET}"
echo ""
echo "KMS key (${kms_alias}):"
key_id=$(aws kms describe-key --key-id "$kms_alias" --query 'KeyMetadata.KeyId' --output text 2>/dev/null || true)

if [ -z "$key_id" ] || [ "$key_id" = "None" ]; then
  echo "  alias ${kms_alias} not found — skipping"
else
  state=$(aws kms describe-key --key-id "$key_id" --query 'KeyMetadata.KeyState' --output text)
  if [ "$state" = "PendingDeletion" ]; then
    echo "  key ${key_id} already PendingDeletion — skipping"
  else
    # delete the alias first so it doesn't linger pointing at a pending key
    aws kms delete-alias --alias-name "$kms_alias" >/dev/null 2>&1 || true
    aws kms schedule-key-deletion --key-id "$key_id" --pending-window-in-days "$kms_window" >/dev/null
    echo "  scheduled key ${key_id} for deletion in ${kms_window} day(s)"
  fi
fi

echo ""
echo "S3 delete complete."
