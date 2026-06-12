#!/usr/bin/env bash
#
# Query the ctl-api `install_workflows` table for "in flight" workflows —
# anything that has not finished yet (finished_at IS NULL), within a recent
# time window. This includes both pending (not yet started) and actively
# running workflows. Joined with `accounts` so we can see which user ran each
# workflow.
#
# Env vars:
#   SINCE       (optional)  postgres interval window; defaults to "2 weeks"
#   LIMIT       (optional)  max rows to return; defaults to 25
#   DB_NAME     (optional)  defaults to "ctl_api"
#   DB_PORT     (optional)  defaults to "5432"
#   DB_ADDR     (optional)  RDS endpoint; auto-discovered if unset
#   SECRET_ARN  (optional)  master-user secret ARN; auto-discovered if unset
#   REGION      (optional)  AWS region; defaults to AWS_REGION / cluster region

set -e
set -o pipefail
set -u

since="${SINCE:-2 weeks}"
limit="${LIMIT:-25}"
db_name="${DB_NAME:-ctl_api}"
db_port="${DB_PORT:-5432}"
region="${REGION:-${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}}"

if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
  echo "[query in-flight workflows] ERROR: LIMIT must be an integer, got: $limit" >&2
  exit 1
fi

# Guard the interval against injection since it's interpolated into SQL.
if ! [[ "$since" =~ ^[0-9]+[[:space:]]*(second|minute|hour|day|week|month|year)s?$ ]]; then
  echo "[query in-flight workflows] ERROR: SINCE must be a simple postgres interval like '2 weeks', got: $since" >&2
  exit 1
fi

echo "[query in-flight workflows] kubectl auth whoami"
kubectl auth whoami -o json | jq -c

db_addr="${DB_ADDR:-}"
secret_arn="${SECRET_ARN:-}"

if [[ -z "$db_addr" || -z "$secret_arn" ]]; then
  echo "[query in-flight workflows] discovering db connection from ctl-api deployment"
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
  echo "[query in-flight workflows] ERROR: could not determine DB_ADDR; set it explicitly" >&2
  exit 1
fi
if [[ -z "$secret_arn" ]]; then
  echo "[query in-flight workflows] ERROR: could not determine SECRET_ARN; set it explicitly" >&2
  exit 1
fi

echo "[query in-flight workflows] db_addr=$db_addr"
echo "[query in-flight workflows] secret_arn=$secret_arn"
echo "[query in-flight workflows] region=$region limit=$limit since='$since'"

echo "[query in-flight workflows] loading db credentials"
secret=$(aws --region "$region" secretsmanager get-secret-value --secret-id="$secret_arn")
admin_username=$(echo "$secret" | jq -r '.SecretString' | jq -r '.username')
admin_password=$(echo "$secret" | jq -r '.SecretString' | jq -r '.password')

echo "[query in-flight workflows] scale up ctl-api-init"
kubectl scale -n ctl-api --replicas=1 deployment/ctl-api-init
kubectl wait deployment -n ctl-api ctl-api-init --for condition=Available=True --timeout=300s

pod=$(kubectl -n ctl-api get pods --selector app=ctl-api-init -o json | jq -r '.items[0].metadata.name')
echo "[query in-flight workflows] using pod: $pod"

# psql renders the aligned table itself — no JSON/jq needed since we're only
# printing to the logs (not persisting outputs). Long text is truncated in SQL
# so columns stay legible.
sql="
SET default_transaction_read_only = on;
SELECT
       -- pending = accepted but not yet started; running = started, not finished.
       CASE WHEN w.started_at IS NULL THEN 'pending' ELSE 'running' END AS state,
       w.type AS type,
       left(
         -- Mirrors Workflow.Name composition in ctl-api workflow.go. In-flight
         -- workflows are never finished, so always present-tense labels.
         (
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
           || COALESCE(' (' || (w.metadata -> 'workflow-name-suffix') || ')', '')
           || CASE
                WHEN w.type = 'action_workflow_run' AND (w.metadata -> 'install_action_workflow_name') IS NOT NULL
                  THEN ' (' || (w.metadata -> 'install_action_workflow_name') || ')'
                ELSE ''
              END
         ), 40
       ) AS name,
       w.status->>'status'        AS status,
       left(o.name, 24)           AS org,
       left(COALESCE(a.email, a.account_type, w.owner_type), 28) AS created_by,
       w.created_at               AS created_at
  FROM install_workflows w
  LEFT JOIN accounts a ON a.id = w.created_by_id
  LEFT JOIN orgs     o ON o.id = w.org_id
  WHERE w.deleted_at = 0
    AND w.finished_at IS NULL
    AND w.created_at >= now() - interval '$since'
  ORDER BY w.created_at DESC
  LIMIT $limit;
"

echo "[query in-flight workflows] in-flight workflows in the last $since:"
# NOTE: intentionally not writing NUON_ACTIONS_OUTPUT_FILEPATH — we don't want
# these query results persisted into install state. Aligned table to logs only.
kubectl --namespace=ctl-api exec -i "$pod" -- \
  env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$admin_username" "PGPASSWORD=$admin_password" \
  psql --no-psqlrc -d "$db_name" -q -P pager=off -c "$sql" \
  | tr -d '\r'

echo "[query in-flight workflows] scale down ctl-api-init"
kubectl scale -n ctl-api --current-replicas=1 --replicas=0 deployment/ctl-api-init

echo "[query in-flight workflows] done"
