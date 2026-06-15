#!/usr/bin/env bash
#
# Inspect a single app via read-only SQL against the ctl-api database.
# Emits one JSON object per line to $NUON_ACTIONS_OUTPUT_FILEPATH:
#   - flat app row (id, name, status, ...)
#   - {"components": [...]}
#   - {"action_workflows": [...]}
#   - {"runbooks": [...]}
#   - {"app_branches": [...]}
#   - {"runner_config": {...}}
#   - {"permissions_config": {"id":"...", "roles":[{...,"policies":[...]}]}}
#
# Required env: APP_ID, REGION (defaults via AWS_REGION).
# Auto-discovers DB_ADDR / SECRET_ARN from the ctl-api-init deployment if unset.

set -e
set -o pipefail
set -u

app_id="${APP_ID:-}"
db_name="${DB_NAME:-ctl_api}"
db_port="${DB_PORT:-5432}"
region="${REGION:-${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}}"

if [[ -z "$app_id" ]]; then
  echo "[inspect_app] ERROR: APP_ID is required" >&2
  exit 1
fi

# App IDs are 26-char ULID/shortid — guard against injection since :'app_id'
# psql binding still requires the value to be sane.
if ! [[ "$app_id" =~ ^[A-Za-z0-9_-]{6,40}$ ]]; then
  echo "[inspect_app] ERROR: APP_ID has unexpected shape: $app_id" >&2
  exit 1
fi

echo "[inspect_app] kubectl auth whoami"
kubectl auth whoami -o json | jq -c

db_addr="${DB_ADDR:-}"
secret_arn="${SECRET_ARN:-}"

if [[ -z "$db_addr" || -z "$secret_arn" ]]; then
  echo "[inspect_app] discovering db connection from ctl-api deployment"
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
  echo "[inspect_app] ERROR: could not determine DB_ADDR; set it explicitly" >&2
  exit 1
fi
if [[ -z "$secret_arn" ]]; then
  echo "[inspect_app] ERROR: could not determine SECRET_ARN; set it explicitly" >&2
  exit 1
fi

echo "[inspect_app] db_addr=$db_addr"
echo "[inspect_app] secret_arn=$secret_arn"
echo "[inspect_app] region=$region app_id=$app_id"

echo "[inspect_app] loading db credentials"
secret=$(aws --region "$region" secretsmanager get-secret-value --secret-id="$secret_arn")
admin_username=$(echo "$secret" | jq -r '.SecretString' | jq -r '.username')
admin_password=$(echo "$secret" | jq -r '.SecretString' | jq -r '.password')

echo "[inspect_app] scale up ctl-api-init"
kubectl scale -n ctl-api --replicas=1 deployment/ctl-api-init
kubectl wait deployment -n ctl-api ctl-api-init --for condition=Available=True --timeout=300s

pod=$(kubectl -n ctl-api get pods --selector app=ctl-api-init -o json | jq -r '.items[0].metadata.name')
echo "[inspect_app] using pod: $pod"

# Single psql session, multiple SELECTs — each emits exactly one JSON line.
# All reads gated by `default_transaction_read_only`.
sql="
SET default_transaction_read_only = on;

-- 1) Flat app row.
SELECT row_to_json(t)
  FROM (
    SELECT id, name, display_name, description, org_id, created_by_id,
           status, status_description, config_repo, config_directory,
           created_at, updated_at
      FROM apps
     WHERE id = :'app_id' AND deleted_at = 0
  ) t;

-- 2) Components.
SELECT json_build_object('components', COALESCE(json_agg(c ORDER BY c.name), '[]'::json))
  FROM (
    SELECT id, name, var_name, type, status, status_description,
           created_by_id, created_at, updated_at
      FROM components
     WHERE app_id = :'app_id' AND deleted_at = 0
  ) c;

-- 3) Action workflows.
SELECT json_build_object('action_workflows', COALESCE(json_agg(w ORDER BY w.name), '[]'::json))
  FROM (
    SELECT id, name, status, status_description,
           created_by_id, created_at, updated_at
      FROM action_workflows
     WHERE app_id = :'app_id' AND deleted_at = 0
  ) w;

-- 4) Runbooks.
SELECT json_build_object('runbooks', COALESCE(json_agg(r ORDER BY r.name), '[]'::json))
  FROM (
    SELECT id, name, description, status, status_description,
           created_by_id, created_at, updated_at
      FROM runbooks
     WHERE app_id = :'app_id' AND deleted_at = 0
  ) r;

-- 5) App branches.
SELECT json_build_object('app_branches', COALESCE(json_agg(b ORDER BY b.name), '[]'::json))
  FROM (
    SELECT id, name, created_by_id, created_at, updated_at
      FROM app_branches
     WHERE app_id = :'app_id' AND deleted_at = 0
  ) b;

-- 6) Current runner config (mirrors AfterQuery's [0] = most recent non-deleted).
SELECT json_build_object('runner_config', COALESCE(to_json(rc), 'null'::json))
  FROM (
    SELECT id, type, helm_driver, instance_type, init_script_url,
           env_vars, app_config_id, created_at
      FROM app_runner_configs
     WHERE app_id = :'app_id' AND deleted_at = 0
     ORDER BY created_at DESC
     LIMIT 1
  ) rc;

-- 6b) Current stack config.
SELECT json_build_object('stack_config', COALESCE(to_json(sc), 'null'::json))
  FROM (
    SELECT id, type, name, description,
           runner_nested_template_url, vpc_nested_template_url,
           custom_nested_stacks, app_config_id, created_at
      FROM app_stack_configs
     WHERE app_id = :'app_id' AND deleted_at = 0
     ORDER BY created_at DESC
     LIMIT 1
  ) sc;

-- 6c) Current sandbox config (+ its polymorphic VCS config).
WITH current_sb AS (
  SELECT id, type, terraform_version, runtime, pulumi_version,
         drift_schedule, max_auto_retries, skip_noops,
         auto_approve_on_policies_passing, aws_region_type,
         variables, env_vars, variables_files, \"references\",
         pulumi_config, operation_roles, app_config_id, created_at
    FROM app_sandbox_configs
   WHERE app_id = :'app_id' AND deleted_at = 0
   ORDER BY created_at DESC
   LIMIT 1
),
vcs AS (
  SELECT 'connected_github' AS vcs_type,
         id, repo, repo_name, repo_owner, directory, branch, path_filter,
         vcs_connection_id, NULL::text AS public_repo_only
    FROM connected_github_vcs_configs
   WHERE component_config_type = 'app_sandbox_configs'
     AND component_config_id IN (SELECT id FROM current_sb)
     AND deleted_at = 0
  UNION ALL
  SELECT 'public_git' AS vcs_type,
         id, repo, NULL::text AS repo_name, NULL::text AS repo_owner,
         directory, branch, path_filter,
         NULL::text AS vcs_connection_id, NULL::text AS public_repo_only
    FROM public_git_vcs_configs
   WHERE component_config_type = 'app_sandbox_configs'
     AND component_config_id IN (SELECT id FROM current_sb)
     AND deleted_at = 0
)
SELECT json_build_object(
         'sandbox_config',
         CASE WHEN (SELECT id FROM current_sb) IS NULL THEN NULL
              ELSE (
                SELECT to_jsonb(current_sb) || jsonb_build_object(
                         'vcs_config', COALESCE(
                           (SELECT to_json(v) FROM vcs v LIMIT 1),
                           'null'::json
                         )
                       )
                  FROM current_sb
              )
         END
       );

-- 7) Current permissions config + its roles + each role's policies.
WITH current_pc AS (
  SELECT id
    FROM app_permissions_configs
   WHERE app_id = :'app_id' AND deleted_at = 0
   ORDER BY created_at DESC
   LIMIT 1
),
roles AS (
  SELECT r.id, r.name, r.display_name, r.description, r.type,
         r.cloud_platform, r.enabled_in_stack, r.created_at,
         COALESCE((
           SELECT json_agg(json_build_object(
                    'id',                  p.id,
                    'name',                p.name,
                    'managed_policy_name', p.managed_policy_name,
                    'gcp_predefined_role', p.gcp_predefined_role,
                    'created_at',          p.created_at
                  ) ORDER BY p.name)
             FROM app_awsiam_policy_configs p
            WHERE p.app_awsiam_role_config_id = r.id
              AND p.deleted_at = 0
         ), '[]'::json) AS policies
    FROM app_awsiam_role_configs r
   WHERE r.owner_type = 'app_permissions_configs'
     AND r.owner_id IN (SELECT id FROM current_pc)
     AND r.deleted_at = 0
)
SELECT json_build_object(
         'permissions_config',
         CASE WHEN (SELECT id FROM current_pc) IS NULL THEN NULL
              ELSE json_build_object(
                'id',    (SELECT id FROM current_pc),
                'roles', COALESCE((SELECT json_agg(to_json(roles) ORDER BY roles.name) FROM roles), '[]'::json)
              )
         END
       );
"

echo "[inspect_app] querying"
out=$(printf '%s' "$sql" | kubectl --namespace=ctl-api exec -i "$pod" -- \
  env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$admin_username" "PGPASSWORD=$admin_password" \
  psql --no-psqlrc -d "$db_name" -q -A -t -P pager=off \
       -v ON_ERROR_STOP=1 -v "app_id=$app_id" \
  | tr -d '\r')

if [[ -z "$out" ]]; then
  echo "[inspect_app] ERROR: no rows returned — app $app_id not found?" >&2
  kubectl scale -n ctl-api --current-replicas=1 --replicas=0 deployment/ctl-api-init || true
  exit 1
fi

# Each non-empty line is one JSON object. Filter blanks and append.
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  echo "$line" >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
done <<< "$out"

echo "[inspect_app] scale down ctl-api-init"
kubectl scale -n ctl-api --current-replicas=1 --replicas=0 deployment/ctl-api-init

echo "[inspect_app] done"
