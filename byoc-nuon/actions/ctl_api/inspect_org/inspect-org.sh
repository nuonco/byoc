#!/usr/bin/env bash
#
# Inspect a single org via read-only SQL against the ctl-api database.
# Emits multiple JSON lines to $NUON_ACTIONS_OUTPUT_FILEPATH:
#   - flat org row
#   - {"apps":            [...]}
#   - {"installs":        [...]}
#   - {"vcs_connections": [...]}
#   - {"roles":           [...]}

set -e
set -o pipefail
set -u

org_id="${ORG_ID:-}"
db_name="${DB_NAME:-ctl_api}"
db_port="${DB_PORT:-5432}"
region="${REGION:-${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}}"

if [[ -z "$org_id" ]]; then echo "[inspect_org] ERROR: ORG_ID required" >&2; exit 1; fi
if ! [[ "$org_id" =~ ^[A-Za-z0-9_-]{6,40}$ ]]; then
  echo "[inspect_org] ERROR: ORG_ID has unexpected shape: $org_id" >&2; exit 1
fi

echo "[inspect_org] kubectl auth whoami"
kubectl auth whoami -o json | jq -c

db_addr="${DB_ADDR:-}"
secret_arn="${SECRET_ARN:-}"

if [[ -z "$db_addr" || -z "$secret_arn" ]]; then
  echo "[inspect_org] discovering db connection from ctl-api deployment"
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

if [[ -z "$db_addr" ]]; then echo "[inspect_org] ERROR: DB_ADDR" >&2; exit 1; fi
if [[ -z "$secret_arn" ]]; then echo "[inspect_org] ERROR: SECRET_ARN" >&2; exit 1; fi

echo "[inspect_org] db_addr=$db_addr secret_arn=$secret_arn region=$region org_id=$org_id"

secret=$(aws --region "$region" secretsmanager get-secret-value --secret-id="$secret_arn")
admin_username=$(echo "$secret" | jq -r '.SecretString' | jq -r '.username')
admin_password=$(echo "$secret" | jq -r '.SecretString' | jq -r '.password')

echo "[inspect_org] scale up ctl-api-init"
kubectl scale -n ctl-api --replicas=1 deployment/ctl-api-init
kubectl wait deployment -n ctl-api ctl-api-init --for condition=Available=True --timeout=300s

pod=$(kubectl -n ctl-api get pods --selector app=ctl-api-init -o json | jq -r '.items[0].metadata.name')
echo "[inspect_org] using pod: $pod"

sql="
SET default_transaction_read_only = on;

-- 1) Flat org row.
SELECT row_to_json(t)
  FROM (
    SELECT id, name, status, status_description, sandbox_mode,
           logo_url, features, tags, created_at, updated_at
      FROM orgs
     WHERE id = :'org_id' AND deleted_at = 0
  ) t;

-- 2) Apps.
SELECT jsonb_build_object('apps', COALESCE(jsonb_agg(a ORDER BY a.created_at DESC), '[]'::jsonb))
  FROM (
    SELECT id, name, display_name, status, created_at, updated_at
      FROM apps
     WHERE org_id = :'org_id' AND deleted_at = 0
  ) a;

-- 3) Installs.
SELECT jsonb_build_object('installs', COALESCE(jsonb_agg(i ORDER BY i.created_at DESC), '[]'::jsonb))
  FROM (
    SELECT id, name, app_id, created_at, updated_at
      FROM installs
     WHERE org_id = :'org_id' AND deleted_at = 0
  ) i;

-- 4) VCS connections.
SELECT jsonb_build_object('vcs_connections', COALESCE(jsonb_agg(v ORDER BY v.created_at DESC), '[]'::jsonb))
  FROM (
    SELECT id, github_install_id, github_account_id, github_account_name,
           status, created_at, updated_at
      FROM vcs_connections
     WHERE org_id = :'org_id' AND deleted_at = 0
  ) v;

-- 5) Roles (with policy count).
SELECT jsonb_build_object('roles', COALESCE(jsonb_agg(r ORDER BY r.created_at), '[]'::jsonb))
  FROM (
    SELECT r.id, r.role_type, r.created_at, r.updated_at,
           (SELECT count(*) FROM policies p WHERE p.role_id = r.id AND p.deleted_at = 0) AS policy_count
      FROM roles r
     WHERE r.org_id = :'org_id' AND r.deleted_at = 0
  ) r;
"

echo "[inspect_org] diagnostic counts for org_id=$org_id"
diag_sql="
SELECT 'orgs_match'           AS t, count(*) FROM orgs            WHERE id = :'org_id'     AND deleted_at = 0
UNION ALL SELECT 'apps_by_org_id',     count(*) FROM apps        WHERE org_id = :'org_id' AND deleted_at = 0
UNION ALL SELECT 'apps_total',         count(*) FROM apps        WHERE                        deleted_at = 0
UNION ALL SELECT 'installs_by_org_id', count(*) FROM installs    WHERE org_id = :'org_id' AND deleted_at = 0
UNION ALL SELECT 'installs_total',     count(*) FROM installs    WHERE                        deleted_at = 0
UNION ALL SELECT 'distinct_apps_org_ids', count(DISTINCT org_id) FROM apps WHERE deleted_at = 0;
"
printf '%s' "$diag_sql" | kubectl --namespace=ctl-api exec -i "$pod" -- \
  env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$admin_username" "PGPASSWORD=$admin_password" \
  psql --no-psqlrc -d "$db_name" -A -t -P pager=off -v ON_ERROR_STOP=1 -v "org_id=$org_id" \
  | tr -d '\r' >&2 || true

echo "[inspect_org] querying"
out=$(printf '%s' "$sql" | kubectl --namespace=ctl-api exec -i "$pod" -- \
  env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$admin_username" "PGPASSWORD=$admin_password" \
  psql --no-psqlrc -d "$db_name" -q -A -t -P pager=off \
       -v ON_ERROR_STOP=1 -v "org_id=$org_id" \
  | tr -d '\r')

if [[ -z "$out" ]]; then
  echo "[inspect_org] ERROR: no rows returned — org $org_id not found?" >&2
  kubectl scale -n ctl-api --current-replicas=1 --replicas=0 deployment/ctl-api-init || true
  exit 1
fi

echo "[inspect_org] raw psql output:" >&2
printf '%s\n' "$out" >&2

# Only append lines that are valid JSON objects — guards against blank lines or
# stray psql messages slipping into the action outputs file.
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  if ! echo "$line" | jq -e -c . >/dev/null 2>&1; then
    echo "[inspect_org] skipping non-JSON line: $line" >&2
    continue
  fi
  echo "$line" >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
done <<< "$out"

echo "[inspect_org] scale down ctl-api-init"
kubectl scale -n ctl-api --current-replicas=1 --replicas=0 deployment/ctl-api-init

echo "[inspect_org] done"
