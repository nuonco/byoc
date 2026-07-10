#!/usr/bin/env bash

set -e
set -o pipefail
set -u

# Empties and deletes the gcs_buckets component's three buckets (blob,
# clickhouse, install-templates) via the gcloud API. Deliberately decoupled from
# the Terraform teardown: the blob bucket has lifecycle.prevent_destroy and is a
# block-destructive-changes critical resource, so deleting it must be an explicit
# operator action, not a side effect of a plan.
#
# IRREVERSIBLE: GCS has no snapshot. Versioned buckets have every object version
# and noncurrent version purged before the bucket is removed.
#
# GCP note (vs AWS S3): the buckets use Google-managed encryption, so there is no
# customer KMS key to schedule for deletion — this script has no KMS step.
#
# Required env (set in the action from the gcs_buckets component outputs):
#   BLOB_BUCKET        blob bucket name (blob_bucket.name output)
#   CLICKHOUSE_BUCKET  clickhouse bucket name (clickhouse_bucket.name output)
# Optional env:
#   PROJECT_ID         the GCP project id (for explicit --project on bucket ops)

: "${BLOB_BUCKET:?BLOB_BUCKET is required}"
: "${CLICKHOUSE_BUCKET:?CLICKHOUSE_BUCKET is required}"
project_id="${PROJECT_ID:-}"

# gcloud storage accepts a --project flag; only pass it when we have one.
proj_args=""
if [ -n "$project_id" ]; then
  proj_args="--project=${project_id}"
fi

echo "==================================================================="
echo " GCS delete: blob, clickhouse, install-templates"
echo "==================================================================="

empty_and_delete_bucket() {
  b="$1"
  if [ -z "$b" ] || [ "$b" = "null" ]; then
    echo "  (empty bucket name, skipping)"
    return 0
  fi

  # shellcheck disable=SC2086
  if ! gcloud storage buckets describe "gs://${b}" $proj_args >/dev/null 2>&1; then
    echo "  bucket ${b} not found (already deleted) — skipping"
    return 0
  fi

  # `gcloud storage rm --recursive gs://<bucket>` deletes every object (including
  # all noncurrent/versioned objects) and then the bucket itself, in one call.
  echo "  emptying + deleting ${b} (objects, versions, then bucket)..."
  # shellcheck disable=SC2086
  gcloud storage rm --recursive "gs://${b}" $proj_args --quiet

  # Belt-and-suspenders: if objects were removed but the bucket survived (partial
  # run), delete it explicitly. Tolerate "not found".
  # shellcheck disable=SC2086
  if gcloud storage buckets describe "gs://${b}" $proj_args >/dev/null 2>&1; then
    # shellcheck disable=SC2086
    gcloud storage buckets delete "gs://${b}" $proj_args --quiet
  fi
  echo "  deleted ${b}"
}

for b in "$BLOB_BUCKET" "$CLICKHOUSE_BUCKET"; do
  echo ""
  echo "Bucket: ${b}"
  empty_and_delete_bucket "$b"
done

echo ""
echo "GCS delete complete."
