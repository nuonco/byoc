#!/usr/bin/env bash
#
# Query the ctl-api `component_builds` table for the most recent builds
# (across all components), joined with `accounts` (who triggered the build),
# `orgs`, and `component_config_connections` -> `components` so we can show
# which component each build belongs to.
#
# component_builds notes (see ctl-api internal/app/component_build.go):
#   - component_id / component_name are NOT columns; they are de-nested from
#     the build's component_config_connection at query time.
#   - status is two-headed: a string `status` column plus a jsonb `status_v2`
#     (CompositeStatus). ctl-api's AfterQuery prefers status_v2 when set, so we
#     COALESCE status_v2->>'status' over the legacy string column.
#
# Env vars:
#   LIMIT       (optional)  max rows to return; defaults to 25
#   DB_NAME     (optional)  defaults to "ctl_api"
#   DB_PORT     (optional)  defaults to "5432"
#   DB_ADDR     (optional)  RDS endpoint; auto-discovered if unset
#   SECRET_ARN  (optional)  master-user secret ARN; auto-discovered if unset
#   REGION      (optional)  AWS region; defaults to AWS_REGION / cluster region

set -e
set -o pipefail
set -u

limit="${LIMIT:-25}"
db_name="${DB_NAME:-ctl_api}"
db_port="${DB_PORT:-5432}"
region="${REGION:-${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}}"

if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
  echo "[query builds] ERROR: LIMIT must be an integer, got: $limit" >&2
  exit 1
fi

echo "[query builds] kubectl auth whoami"
kubectl auth whoami -o json | jq -c

db_addr="${DB_ADDR:-}"
secret_arn="${SECRET_ARN:-}"

if [[ -z "$db_addr" || -z "$secret_arn" ]]; then
  echo "[query builds] discovering db connection from ctl-api deployment"
  if [[ -z "$db_addr" ]]; then
    db_addr=$(kubectl -n ctl-api get deploy ctl-api-init -o json \
      | jq -r '.spec.template.spec.containers[0].env[] | select(.name=="PGHOST" or .name=="DB_HOST" or .name=="DB_ADDR") | .value' \
      | head -n1)
  fi
  if [[ -z "$secret_arn" ]]; then
    secret_arn=$(kubectl -n ctl-api get deploy ctl-api-init -o json \
      | jq -r '.spec.template.spec.containers[0].env[] | select(.name=="DB_MASTER_SECRET_ARN" or .name=="SECRET_ARN") | .value' \
      | head -n1)
  fi
fi

if [[ -z "$db_addr" ]]; then
  echo "[query builds] ERROR: could not determine DB_ADDR; set it explicitly" >&2
  exit 1
fi
if [[ -z "$secret_arn" ]]; then
  echo "[query builds] ERROR: could not determine SECRET_ARN; set it explicitly" >&2
  exit 1
fi

echo "[query builds] db_addr=$db_addr"
echo "[query builds] secret_arn=$secret_arn"
echo "[query builds] region=$region limit=$limit"

echo "[query builds] loading db credentials"
secret=$(aws --region "$region" secretsmanager get-secret-value --secret-id="$secret_arn")
admin_username=$(echo "$secret" | jq -r '.SecretString' | jq -r '.username')
admin_password=$(echo "$secret" | jq -r '.SecretString' | jq -r '.password')

# Ensure ctl-api-init is scaled back down even if the query fails partway
# through (set -e would otherwise skip the explicit scale-down below and leave
# a DB-access pod running). The flag keeps the trap a no-op until we scale up.
scaled_up=0
cleanup() {
  if [[ "$scaled_up" == "1" ]]; then
    echo "[query builds] cleanup: scaling down ctl-api-init"
    kubectl scale -n ctl-api --replicas=0 deployment/ctl-api-init >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

echo "[query builds] scale up ctl-api-init"
kubectl scale -n ctl-api --replicas=1 deployment/ctl-api-init
scaled_up=1
kubectl wait deployment -n ctl-api ctl-api-init --for condition=Available=True --timeout=300s

pod=$(kubectl -n ctl-api get pods --selector app=ctl-api-init --field-selector=status.phase=Running -o json \
  | jq -r '[.items[] | select(.metadata.deletionTimestamp == null)] | sort_by(.metadata.creationTimestamp) | last | .metadata.name')
if [[ -z "$pod" || "$pod" == "null" ]]; then
  echo "[query builds] ERROR: no running ctl-api-init pod found" >&2
  exit 1
fi
echo "[query builds] using pod: $pod"

sql="
SET default_transaction_read_only = on;
SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.build_created_at DESC), '[]'::json)::text
FROM (
  SELECT b.id                AS build_id,
         COALESCE(NULLIF(b.status_v2->>'status', ''), b.status)                               AS build_status,
         COALESCE(NULLIF(b.status_v2->>'status_human_description', ''), b.status_description) AS build_status_description,
         b.created_at         AS build_created_at,
         b.updated_at         AS build_updated_at,
         -- git_ref, checksum, no_op and the image-source fields were added with
         -- later ctl-api features and may not exist on older schemas. Read them
         -- through to_jsonb(b) so a missing column yields NULL rather than
         -- erroring the whole query.
         to_jsonb(b)->>'resolved_at'                       AS build_resolved_at,
         COALESCE((to_jsonb(b)->>'no_op')::boolean, false) AS build_no_op,
         to_jsonb(b)->>'git_ref'                           AS git_ref,
         to_jsonb(b)->>'checksum'                          AS checksum,
         to_jsonb(b)->>'source_ref'                        AS source_ref,
         to_jsonb(b)->>'source_image'                      AS source_image,
         to_jsonb(b)->>'resolved_tag'                      AS resolved_tag,
         to_jsonb(b)->>'source_digest'                     AS source_digest,
         to_jsonb(b)->>'source_media_type'                 AS source_media_type,
         b.org_id             AS org_id,
         o.name               AS org_name,
         b.created_by_id      AS created_by_id,
         a.email              AS created_by_email,
         a.subject            AS created_by_subject,
         a.account_type       AS created_by_account_type,
         ccc.component_id     AS component_id,
         c.name               AS component_name,
         c.type               AS component_type
  FROM component_builds b
  LEFT JOIN accounts a ON a.id = b.created_by_id
  LEFT JOIN orgs     o ON o.id = b.org_id
  LEFT JOIN component_config_connections ccc ON ccc.id = b.component_config_connection_id
  LEFT JOIN components c ON c.id = ccc.component_id
  WHERE b.deleted_at = 0
  ORDER BY b.created_at DESC
  LIMIT $limit
) t;
"

echo "[query builds] running query"
builds_json=$(kubectl --namespace=ctl-api exec -i "$pod" -- \
  env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$admin_username" "PGPASSWORD=$admin_password" \
  psql --no-psqlrc -d "$db_name" -A -t -q -c "$sql" \
  | tr -d '\r' | { grep -E '^[[\{]' || true; } | tail -n 1)

echo "[query builds] scale down ctl-api-init"
kubectl scale -n ctl-api --current-replicas=1 --replicas=0 deployment/ctl-api-init
scaled_up=0

if [[ -z "$builds_json" ]]; then
  builds_json='[]'
fi

# Validate it's parseable JSON; fail loud if not.
echo "$builds_json" | jq . > /dev/null

if [[ -n "${NUON_ACTIONS_OUTPUT_FILEPATH:-}" ]]; then
  echo "[query builds] writing outputs"
  jq -cn --argjson builds "$builds_json" '{builds: $builds}' > "$NUON_ACTIONS_OUTPUT_FILEPATH"
fi

echo "[query builds] done"
