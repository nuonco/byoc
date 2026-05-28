#!/usr/bin/env bash
#
# Query the ctl-api `install_workflows` table for the most recent workflows
# (across all types), joined with `accounts` so we can see which user ran
# each workflow.
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
  echo "[query workflows] ERROR: LIMIT must be an integer, got: $limit" >&2
  exit 1
fi

echo "[query workflows] kubectl auth whoami"
kubectl auth whoami -o json | jq -c

db_addr="${DB_ADDR:-}"
secret_arn="${SECRET_ARN:-}"

if [[ -z "$db_addr" || -z "$secret_arn" ]]; then
  echo "[query workflows] discovering db connection from ctl-api deployment"
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
  echo "[query workflows] ERROR: could not determine DB_ADDR; set it explicitly" >&2
  exit 1
fi
if [[ -z "$secret_arn" ]]; then
  echo "[query workflows] ERROR: could not determine SECRET_ARN; set it explicitly" >&2
  exit 1
fi

echo "[query workflows] db_addr=$db_addr"
echo "[query workflows] secret_arn=$secret_arn"
echo "[query workflows] region=$region limit=$limit"

echo "[query workflows] loading db credentials"
secret=$(aws --region "$region" secretsmanager get-secret-value --secret-id="$secret_arn")
admin_username=$(echo "$secret" | jq -r '.SecretString' | jq -r '.username')
admin_password=$(echo "$secret" | jq -r '.SecretString' | jq -r '.password')

echo "[query workflows] scale up ctl-api-init"
kubectl scale -n ctl-api --replicas=1 deployment/ctl-api-init
kubectl wait deployment -n ctl-api ctl-api-init --for condition=Available=True --timeout=300s

pod=$(kubectl -n ctl-api get pods --selector app=ctl-api-init -o json | jq -r '.items[0].metadata.name')
echo "[query workflows] using pod: $pod"

sql="
SET default_transaction_read_only = on;
SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.workflow_created_at DESC), '[]'::json)::text
FROM (
  SELECT w.id                AS workflow_id,
         w.type              AS workflow_type,
         -- Mirrors Workflow.Name composition in ctl-api workflow.go:
         --   <type label> [ (workflow-name-suffix) ] [ (install_action_workflow_name) ]
         -- Uses past-tense labels when finished, present-tense otherwise.
         (
           CASE
             WHEN w.finished_at IS NOT NULL THEN
               CASE w.type
                 WHEN 'provision'                     THEN 'Provisioned install'
                 WHEN 'reprovision'                   THEN 'Reprovisioned install'
                 WHEN 'reprovision_sandbox'           THEN 'Reprovisioned sandbox'
                 WHEN 'drift_run_reprovision_sandbox' THEN 'Reprovisioned sandbox'
                 WHEN 'deprovision'                   THEN 'Deprovisioned install'
                 WHEN 'manual_deploy'                 THEN 'Deployed to install'
                 WHEN 'drift_run'                     THEN 'Deployed to install'
                 WHEN 'input_update'                  THEN 'Updated Input'
                 WHEN 'teardown_components'           THEN 'Tore down all components'
                 WHEN 'deploy_components'             THEN 'Deployed all components'
                 WHEN 'sync_secrets'                  THEN 'Synced secrets'
                 WHEN 'action_workflow_run'           THEN 'Action run'
                 WHEN 'app_config_build'              THEN 'Built app config components'
                 ELSE w.type::text
               END
             ELSE
               CASE w.type
                 WHEN 'provision'                     THEN 'Provisioning install'
                 WHEN 'reprovision'                   THEN 'Reprovisioning install'
                 WHEN 'reprovision_sandbox'           THEN 'Reprovisioning sandbox'
                 WHEN 'drift_run_reprovision_sandbox' THEN 'Reprovisioning sandbox'
                 WHEN 'deprovision'                   THEN 'Deprovisioning install'
                 WHEN 'manual_deploy'                 THEN 'Deploying to install'
                 WHEN 'drift_run'                     THEN 'Deploying to install'
                 WHEN 'input_update'                  THEN 'Input Update'
                 WHEN 'teardown_components'           THEN 'Tearing down all components'
                 WHEN 'deploy_components'             THEN 'Deploying all components'
                 WHEN 'sync_secrets'                  THEN 'Syncing secrets'
                 WHEN 'action_workflow_run'           THEN 'Action run'
                 WHEN 'app_config_build'              THEN 'Building app config components'
                 ELSE w.type::text
               END
           END
           || COALESCE(' (' || (w.metadata -> 'workflow-name-suffix') || ')', '')
           || CASE
                WHEN w.type = 'action_workflow_run' AND (w.metadata -> 'install_action_workflow_name') IS NOT NULL
                  THEN ' (' || (w.metadata -> 'install_action_workflow_name') || ')'
                ELSE ''
              END
         ) AS workflow_name,
         w.status->>'status' AS workflow_status,
         w.created_at        AS workflow_created_at,
         w.updated_at        AS workflow_updated_at,
         w.started_at        AS workflow_started_at,
         w.finished_at       AS workflow_finished_at,
         w.org_id            AS org_id,
         o.name              AS org_name,
         w.owner_id          AS owner_id,
         w.owner_type        AS owner_type,
         (w.metadata -> 'owner_name') AS owner_name,
         w.created_by_id     AS created_by_id,
         a.email             AS created_by_email,
         a.subject           AS created_by_subject,
         a.account_type      AS created_by_account_type
  FROM install_workflows w
  LEFT JOIN accounts a ON a.id = w.created_by_id
  LEFT JOIN orgs     o ON o.id = w.org_id
  WHERE w.deleted_at = 0
  ORDER BY w.created_at DESC
  LIMIT $limit
) t;
"

echo "[query workflows] running query"
workflows_json=$(kubectl --namespace=ctl-api exec -i "$pod" -- \
  env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$admin_username" "PGPASSWORD=$admin_password" \
  psql --no-psqlrc -d "$db_name" -A -t -q -c "$sql" \
  | tr -d '\r' | { grep -E '^[[\{]' || true; } | tail -n 1)

echo "[query workflows] scale down ctl-api-init"
kubectl scale -n ctl-api --current-replicas=1 --replicas=0 deployment/ctl-api-init

if [[ -z "$workflows_json" ]]; then
  workflows_json='[]'
fi

# Validate it's parseable JSON; fail loud if not.
echo "$workflows_json" | jq . > /dev/null

if [[ -n "${NUON_ACTIONS_OUTPUT_FILEPATH:-}" ]]; then
  echo "[query workflows] writing outputs"
  jq -cn --argjson wfs "$workflows_json" '{workflows: $wfs}' > "$NUON_ACTIONS_OUTPUT_FILEPATH"
fi

echo "[query workflows] done"
