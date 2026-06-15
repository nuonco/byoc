#!/usr/bin/env bash
#
# Inspect installs via read-only SQL against the ctl-api database.
# Emits one JSON object per install to $NUON_ACTIONS_OUTPUT_FILEPATH, keyed by
# "<priority>_<id>" so the runbook sorts error/active first.
#
# Sources (all Postgres):
#   installs_view_v8 (sandbox_status, component_statuses, install_number),
#   runner_groups + runners (RunnerGroup is polymorphic on Owner = 'installs'),
#   apps, orgs (for app_name / org_name).

set -e
set -o pipefail
set -u

db_name="${DB_NAME:-ctl_api}"
db_port="${DB_PORT:-5432}"
region="${REGION:-${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}}"

echo "[inspect_installs] kubectl auth whoami"
kubectl auth whoami -o json | jq -c

db_addr="${DB_ADDR:-}"
secret_arn="${SECRET_ARN:-}"

if [[ -z "$db_addr" || -z "$secret_arn" ]]; then
  echo "[inspect_installs] discovering db connection from ctl-api deployment"
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
  echo "[inspect_installs] ERROR: could not determine DB_ADDR; set it explicitly" >&2
  exit 1
fi
if [[ -z "$secret_arn" ]]; then
  echo "[inspect_installs] ERROR: could not determine SECRET_ARN; set it explicitly" >&2
  exit 1
fi

echo "[inspect_installs] db_addr=$db_addr"
echo "[inspect_installs] secret_arn=$secret_arn"
echo "[inspect_installs] region=$region"

echo "[inspect_installs] loading db credentials"
secret=$(aws --region "$region" secretsmanager get-secret-value --secret-id="$secret_arn")
admin_username=$(echo "$secret" | jq -r '.SecretString' | jq -r '.username')
admin_password=$(echo "$secret" | jq -r '.SecretString' | jq -r '.password')

echo "[inspect_installs] scale up ctl-api-init"
kubectl scale -n ctl-api --replicas=1 deployment/ctl-api-init
kubectl wait deployment -n ctl-api ctl-api-init --for condition=Available=True --timeout=300s

pod=$(kubectl -n ctl-api get pods --selector app=ctl-api-init -o json | jq -r '.items[0].metadata.name')
echo "[inspect_installs] using pod: $pod"

# Composite component status mirrors compositeComponentStatus() in app/install.go:
#   no statuses     → pending
#   any 'error'     → error
#   all 'active'    → active
#   otherwise       → pending
sql="
SET default_transaction_read_only = on;
WITH install_runner AS (
  SELECT DISTINCT ON (rg.owner_id)
         rg.owner_id   AS install_id,
         r.id          AS runner_id,
         r.status      AS runner_status,
         r.status_description AS runner_status_description
    FROM runner_groups rg
    JOIN runners r ON r.runner_group_id = rg.id AND r.deleted_at = 0
   WHERE rg.owner_type = 'installs' AND rg.deleted_at = 0
   ORDER BY rg.owner_id, r.created_at DESC
)
SELECT json_build_object(
         'id',                         i.id,
         'name',                       i.name,
         'app_id',                     i.app_id,
         'app_name',                   a.name,
         'org_id',                     i.org_id,
         'org_name',                   o.name,
         'install_number',             i.install_number,
         'platform',
            CASE
              WHEN arc.type IN ('aws_ecs','aws_eks','aws')        THEN 'aws'
              WHEN arc.type IN ('azure_aks','azure_acs','azure')  THEN 'azure'
              WHEN arc.type IN ('gcp','gcp_gke')                  THEN 'gcp'
              ELSE 'unknown'
            END,
         'runner_type',                arc.type,
         'region',                     COALESCE(aws.region, gcp.region, azure.location),
         'runner_id',                  ir.runner_id,
         'runner_status',              COALESCE(ir.runner_status, 'deprovisioned'),
         'runner_status_description',  ir.runner_status_description,
         'sandbox_status',             i.sandbox_status,
         'component_status',
            CASE
              WHEN i.component_statuses IS NULL
                OR array_length(avals(i.component_statuses), 1) IS NULL THEN 'pending'
              WHEN 'error' = ANY(avals(i.component_statuses))            THEN 'error'
              WHEN array_length(array_remove(avals(i.component_statuses), 'active'), 1) IS NULL THEN 'active'
              ELSE 'pending'
            END,
         'status',
            CASE
              WHEN COALESCE(ir.runner_status, 'deprovisioned') = 'error' THEN 'error'
              WHEN i.sandbox_status = 'error'                            THEN 'error'
              WHEN 'error' = ANY(avals(COALESCE(i.component_statuses, ''::hstore))) THEN 'error'
              WHEN COALESCE(ir.runner_status, '') = 'active'
               AND COALESCE(i.sandbox_status, '') IN ('active','healthy','ready')
                                                                         THEN 'active'
              ELSE 'pending'
            END,
         'created_at',                 i.created_at,
         'updated_at',                 i.updated_at
       )::text
  FROM installs_view_v8 i
  LEFT JOIN install_runner ir ON ir.install_id = i.id
  LEFT JOIN apps a ON a.id = i.app_id AND a.deleted_at = 0
  LEFT JOIN orgs o ON o.id = i.org_id AND o.deleted_at = 0
  LEFT JOIN app_runner_configs arc ON arc.id = i.app_runner_config_id AND arc.deleted_at = 0
  LEFT JOIN aws_accounts   aws   ON aws.install_id   = i.id AND aws.deleted_at   = 0
  LEFT JOIN gcp_accounts   gcp   ON gcp.install_id   = i.id AND gcp.deleted_at   = 0
  LEFT JOIN azure_accounts azure ON azure.install_id = i.id AND azure.deleted_at = 0
 WHERE i.deleted_at = 0
 ORDER BY i.created_at DESC;
"

echo "[inspect_installs] querying installs"
printf '%s' "$sql" | kubectl --namespace=ctl-api exec -i "$pod" -- \
  env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$admin_username" "PGPASSWORD=$admin_password" \
  psql --no-psqlrc -d "$db_name" -q -A -t -P pager=off -v ON_ERROR_STOP=1 \
  | tr -d '\r' \
  | while IFS= read -r row; do
      [[ -z "$row" ]] && continue
      echo "$row" | jq -c '
        ({"error":"0","active":"1"}[(.status // "unknown")] // "2") as $prio
        | {("\($prio)_\(.id)"): .}
      ' >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
    done

echo "[inspect_installs] scale down ctl-api-init"
kubectl scale -n ctl-api --current-replicas=1 --replicas=0 deployment/ctl-api-init

echo "[inspect_installs] done"
