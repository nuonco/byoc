#!/usr/bin/env bash
#
# Inspect a single install via read-only SQL against the ctl-api database.
# Emits one JSON object per line to $NUON_ACTIONS_OUTPUT_FILEPATH:
#   - flat install row (id, name, platform, region, runner_status, ...)
#   - {"components":     [...]}
#   - {"sandbox":        {...}}
#   - {"stack":          {...}}
#
# Required env: INSTALL_ID, REGION (defaults via AWS_REGION).
# Auto-discovers DB_ADDR / SECRET_ARN from the ctl-api-init deployment if unset.

set -e
set -o pipefail
set -u

install_id="${INSTALL_ID:-}"
db_name="${DB_NAME:-ctl_api}"
db_port="${DB_PORT:-5432}"
region="${REGION:-${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}}"

if [[ -z "$install_id" ]]; then
  echo "[inspect_install] ERROR: INSTALL_ID is required" >&2
  exit 1
fi

if ! [[ "$install_id" =~ ^[A-Za-z0-9_-]{6,40}$ ]]; then
  echo "[inspect_install] ERROR: INSTALL_ID has unexpected shape: $install_id" >&2
  exit 1
fi

echo "[inspect_install] kubectl auth whoami"
kubectl auth whoami -o json | jq -c

db_addr="${DB_ADDR:-}"
secret_arn="${SECRET_ARN:-}"

if [[ -z "$db_addr" || -z "$secret_arn" ]]; then
  echo "[inspect_install] discovering db connection from ctl-api deployment"
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
  echo "[inspect_install] ERROR: could not determine DB_ADDR; set it explicitly" >&2
  exit 1
fi
if [[ -z "$secret_arn" ]]; then
  echo "[inspect_install] ERROR: could not determine SECRET_ARN; set it explicitly" >&2
  exit 1
fi

echo "[inspect_install] db_addr=$db_addr"
echo "[inspect_install] secret_arn=$secret_arn"
echo "[inspect_install] region=$region install_id=$install_id"

echo "[inspect_install] loading db credentials"
secret=$(aws --region "$region" secretsmanager get-secret-value --secret-id="$secret_arn")
admin_username=$(echo "$secret" | jq -r '.SecretString' | jq -r '.username')
admin_password=$(echo "$secret" | jq -r '.SecretString' | jq -r '.password')

echo "[inspect_install] scale up ctl-api-init"
kubectl scale -n ctl-api --replicas=1 deployment/ctl-api-init
kubectl wait deployment -n ctl-api ctl-api-init --for condition=Available=True --timeout=300s

pod=$(kubectl -n ctl-api get pods --selector app=ctl-api-init -o json | jq -r '.items[0].metadata.name')
echo "[inspect_install] using pod: $pod"

sql="
SET default_transaction_read_only = on;

-- 1) Flat install row with derived fields (platform, region, runner status, component status).
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
SELECT row_to_json(t)
  FROM (
    SELECT i.id, i.name, i.app_id, a.name AS app_name,
           i.org_id, o.name AS org_name,
           i.install_number,
           CASE
             WHEN arc.type IN ('aws_ecs','aws_eks','aws')       THEN 'aws'
             WHEN arc.type IN ('azure_aks','azure_acs','azure') THEN 'azure'
             WHEN arc.type IN ('gcp','gcp_gke')                 THEN 'gcp'
             ELSE 'unknown'
           END AS platform,
           arc.type AS runner_type,
           COALESCE(aws.region, gcp.region, azure.location) AS region,
           ir.runner_id,
           COALESCE(ir.runner_status, 'deprovisioned') AS runner_status,
           ir.runner_status_description,
           i.sandbox_status,
           CASE
             WHEN i.component_statuses IS NULL
               OR array_length(avals(i.component_statuses), 1) IS NULL THEN 'pending'
             WHEN 'error' = ANY(avals(i.component_statuses))            THEN 'error'
             WHEN array_length(array_remove(avals(i.component_statuses), 'active'), 1) IS NULL THEN 'active'
             ELSE 'pending'
           END AS component_status,
           i.app_config_id, i.app_runner_config_id, i.app_sandbox_config_id,
           i.sandbox_mode, i.created_at, i.updated_at
      FROM installs_view_v8 i
      LEFT JOIN install_runner ir ON ir.install_id = i.id
      LEFT JOIN apps a ON a.id = i.app_id AND a.deleted_at = 0
      LEFT JOIN orgs o ON o.id = i.org_id AND o.deleted_at = 0
      LEFT JOIN app_runner_configs arc ON arc.id = i.app_runner_config_id AND arc.deleted_at = 0
      LEFT JOIN aws_accounts   aws   ON aws.install_id   = i.id AND aws.deleted_at   = 0
      LEFT JOIN gcp_accounts   gcp   ON gcp.install_id   = i.id AND gcp.deleted_at   = 0
      LEFT JOIN azure_accounts azure ON azure.install_id = i.id AND azure.deleted_at = 0
     WHERE i.id = :'install_id' AND i.deleted_at = 0
  ) t;

-- 2) Install components.
SELECT json_build_object('components', COALESCE(json_agg(c ORDER BY c.created_at), '[]'::json))
  FROM (
    SELECT ic.id, ic.component_id, c.name AS component_name, c.var_name AS component_var_name,
           c.type AS component_type, ic.status, ic.status_description,
           ic.created_at, ic.updated_at
      FROM install_components ic
      LEFT JOIN components c ON c.id = ic.component_id AND c.deleted_at = 0
     WHERE ic.install_id = :'install_id' AND ic.deleted_at = 0
  ) c;

-- 3) Install sandbox (current).
SELECT json_build_object('sandbox', COALESCE(to_json(sb), 'null'::json))
  FROM (
    SELECT id, status, status_description, status_v2,
           created_at, updated_at
      FROM install_sandboxes
     WHERE install_id = :'install_id' AND deleted_at = 0
     ORDER BY created_at DESC
     LIMIT 1
  ) sb;

-- 4) Install stack (current) + its latest outputs hstore as JSON.
SELECT json_build_object('stack',
         CASE WHEN s.id IS NULL THEN NULL
              ELSE to_jsonb(s) || jsonb_build_object('outputs', COALESCE(o.outputs, '{}'::json))
         END)
  FROM (
    SELECT id, install_id, created_at, updated_at
      FROM install_stacks
     WHERE install_id = :'install_id' AND deleted_at = 0
     ORDER BY created_at DESC
     LIMIT 1
  ) s
  LEFT JOIN LATERAL (
    SELECT COALESCE(hstore_to_json(iso.data), '{}'::json) AS outputs
      FROM install_stack_outputs iso
     WHERE iso.install_stack_id = s.id AND iso.deleted_at = 0
     ORDER BY iso.created_at DESC
     LIMIT 1
  ) o ON TRUE;
"

echo "[inspect_install] querying"
out=$(printf '%s' "$sql" | kubectl --namespace=ctl-api exec -i "$pod" -- \
  env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$admin_username" "PGPASSWORD=$admin_password" \
  psql --no-psqlrc -d "$db_name" -q -A -t -P pager=off \
       -v ON_ERROR_STOP=1 -v "install_id=$install_id" \
  | tr -d '\r')

if [[ -z "$out" ]]; then
  echo "[inspect_install] ERROR: no rows returned — install $install_id not found?" >&2
  kubectl scale -n ctl-api --current-replicas=1 --replicas=0 deployment/ctl-api-init || true
  exit 1
fi

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  echo "$line" >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
done <<< "$out"

echo "[inspect_install] scale down ctl-api-init"
kubectl scale -n ctl-api --current-replicas=1 --replicas=0 deployment/ctl-api-init

echo "[inspect_install] done"
