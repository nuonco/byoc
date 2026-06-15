#!/usr/bin/env bash
#
# Inspect orgs via read-only SQL against the ctl-api `orgs` table.
# Emits one JSON object per org to $NUON_ACTIONS_OUTPUT_FILEPATH, keyed by id.

set -e
set -o pipefail
set -u

db_name="${DB_NAME:-ctl_api}"
db_port="${DB_PORT:-5432}"
region="${REGION:-${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}}"

echo "[inspect_orgs] kubectl auth whoami"
kubectl auth whoami -o json | jq -c

db_addr="${DB_ADDR:-}"
secret_arn="${SECRET_ARN:-}"

if [[ -z "$db_addr" || -z "$secret_arn" ]]; then
  echo "[inspect_orgs] discovering db connection from ctl-api deployment"
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

if [[ -z "$db_addr" ]]; then echo "[inspect_orgs] ERROR: DB_ADDR" >&2; exit 1; fi
if [[ -z "$secret_arn" ]]; then echo "[inspect_orgs] ERROR: SECRET_ARN" >&2; exit 1; fi

echo "[inspect_orgs] db_addr=$db_addr secret_arn=$secret_arn region=$region"

secret=$(aws --region "$region" secretsmanager get-secret-value --secret-id="$secret_arn")
admin_username=$(echo "$secret" | jq -r '.SecretString' | jq -r '.username')
admin_password=$(echo "$secret" | jq -r '.SecretString' | jq -r '.password')

echo "[inspect_orgs] scale up ctl-api-init"
kubectl scale -n ctl-api --replicas=1 deployment/ctl-api-init
kubectl wait deployment -n ctl-api ctl-api-init --for condition=Available=True --timeout=300s

pod=$(kubectl -n ctl-api get pods --selector app=ctl-api-init -o json | jq -r '.items[0].metadata.name')
echo "[inspect_orgs] using pod: $pod"

sql="
SET default_transaction_read_only = on;
SELECT json_build_object(
         'id',           o.id,
         'name',         o.name,
         'status',       o.status,
         'sandbox_mode', o.sandbox_mode,
         'app_count',     (SELECT count(*) FROM apps     WHERE org_id = o.id AND deleted_at = 0),
         'install_count', (SELECT count(*) FROM installs WHERE org_id = o.id AND deleted_at = 0),
         'created_at',   o.created_at,
         'updated_at',   o.updated_at
       )::text
  FROM orgs o
 WHERE o.deleted_at = 0
 ORDER BY o.created_at DESC;
"

echo "[inspect_orgs] querying orgs"
printf '%s' "$sql" | kubectl --namespace=ctl-api exec -i "$pod" -- \
  env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$admin_username" "PGPASSWORD=$admin_password" \
  psql --no-psqlrc -d "$db_name" -q -A -t -P pager=off -v ON_ERROR_STOP=1 \
  | tr -d '\r' \
  | while IFS= read -r row; do
      [[ -z "$row" ]] && continue
      echo "$row" | jq -c '{(.id): .}' >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
    done

echo "[inspect_orgs] scale down ctl-api-init"
kubectl scale -n ctl-api --current-replicas=1 --replicas=0 deployment/ctl-api-init

echo "[inspect_orgs] done"
