#!/usr/bin/env bash
#
# Query ctl-api for recent install workflows joined with their step groups,
# steps, and the queue_signals attached to each (step-group level and step
# level). Useful for debugging stuck or retrying workflows.

set -e
set -o pipefail
set -u

db_name="$DB_NAME"
db_user="$DB_USER"
db_addr="$DB_ADDR"
db_port="$DB_PORT"
limit="${LIMIT:-10}"
workflow_id="${WORKFLOW_ID:-}"

if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
  echo "[query workflow steps] ERROR: LIMIT must be an integer, got: $limit" >&2
  exit 1
fi

# WORKFLOW_ID is an opaque ctl-api id (e.g. inwh3px7j15xbeey92mv0bbghk). Enforce
# a conservative charset so it can be safely interpolated into the SQL below.
if [[ -n "$workflow_id" ]] && ! [[ "$workflow_id" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "[query workflow steps] ERROR: WORKFLOW_ID contains unexpected characters: $workflow_id" >&2
  exit 1
fi

if [[ -n "$workflow_id" ]]; then
  workflow_filter="AND id = '$workflow_id'"
else
  workflow_filter=""
fi

echo "[query workflow steps] kubectl auth whoami"
kubectl auth whoami -o json | jq -c

echo "[query workflow steps] scale up ctl-api-init"
kubectl scale -n ctl-api --replicas=1 deployment/ctl-api-init
kubectl wait deployment -n ctl-api ctl-api-init --for condition=Available=True --timeout=300s

pod=$(kubectl -n ctl-api get pods --selector app=ctl-api-init --field-selector=status.phase=Running -o json \
  | jq -r '[.items[] | select(.metadata.deletionTimestamp == null)] | sort_by(.metadata.creationTimestamp) | last | .metadata.name')
if [[ -z "$pod" || "$pod" == "null" ]]; then
  echo "[query workflow steps] ERROR: no running ctl-api-init pod found" >&2
  exit 1
fi
echo "[query workflow steps] using pod: $pod"

# Query as the ctl-api IAM role (the table owner) via Cloud SQL IAM auth. The
# nuon-db admin user is NOT the owner and gets "permission denied". Impersonate
# the ctl-api SA on the runner (ctl_api_wi grants the runner token-creator on it)
# to mint a sqlservice.login-scoped token, used as the DB password over SSL.
: "${CTL_API_SA_EMAIL:?CTL_API_SA_EMAIL is required (ctl_api_wi.service_account_email)}"
echo "[query workflow steps] minting a Cloud SQL login token as ${CTL_API_SA_EMAIL}"
db_token=$(gcloud auth print-access-token \
  --impersonate-service-account="$CTL_API_SA_EMAIL" \
  --scopes=https://www.googleapis.com/auth/sqlservice.login)
if [[ -z "$db_token" ]]; then
  echo "[query workflow steps] ERROR: failed to mint a login token as $CTL_API_SA_EMAIL." >&2
  exit 1
fi

read -r -d '' sql <<SQL || true
SET default_transaction_read_only = on;
WITH target_workflows AS (
    SELECT *
    FROM install_workflows
    WHERE deleted_at = 0
      ${workflow_filter}
    ORDER BY created_at DESC
    LIMIT ${limit}
),
step_signals AS (
    SELECT owner_id AS step_id,
           string_agg(type || ':' || (status->>'status'), ', ' ORDER BY enqueued) AS signals
    FROM queue_signals
    WHERE owner_type = 'install_workflow_steps'
      AND deleted_at = 0
    GROUP BY owner_id
),
sg_signals AS (
    SELECT owner_id AS step_group_id,
           string_agg(type || ':' || (status->>'status'), ', ' ORDER BY enqueued) AS signals
    FROM queue_signals
    WHERE owner_type = 'workflow_step_groups'
      AND deleted_at = 0
    GROUP BY owner_id
)
SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)::text FROM (
SELECT
    w.id                                    AS workflow_id,
    w.type                                  AS workflow_type,
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
    )                                       AS workflow_name,
    w.status->>'status'                     AS workflow_status,
    w.owner_id                              AS install_id,
    i.name                                  AS install_name,
    w.org_id,
    o.name                                  AS org_name,
    w.approval_option,
    w.result_directive                      AS wf_result_directive,
    w.created_at                            AS workflow_created_at,
    w.started_at                            AS workflow_started_at,
    w.finished_at                           AS workflow_finished_at,
    a.email                                 AS created_by_email,

    sg.id                                   AS step_group_id,
    sg.name                                 AS step_group_name,
    sg.group_idx,
    sg.parallel                             AS group_parallel,
    sg.status->>'status'                    AS step_group_status,
    sg.result_directive                     AS sg_result_directive,
    sgs.signals                             AS sg_signals,

    s.id                                    AS step_id,
    s.name                                  AS step_name,
    s.idx                                   AS step_idx,
    s.execution_type,
    s.status->>'status'                     AS step_status,
    s.result_directive                      AS step_result_directive,
    s.retryable,
    s.skippable,
    s.retried,
    s.started_at                            AS step_started_at,
    s.finished_at                           AS step_finished_at,

    s.step_target_id,
    s.step_target_type,

    ss.signals                              AS step_signals

FROM target_workflows w
JOIN accounts a
    ON a.id = w.created_by_id
LEFT JOIN installs i
    ON i.id = w.owner_id
    AND i.deleted_at = 0
LEFT JOIN orgs o
    ON o.id = w.org_id
    AND o.deleted_at = 0
LEFT JOIN workflow_step_groups sg
    ON sg.workflow_id = w.id
    AND sg.deleted_at = 0
LEFT JOIN install_workflow_steps s
    ON s.workflow_step_group_id = sg.id
    AND s.deleted_at = 0
LEFT JOIN sg_signals sgs
    ON sgs.step_group_id = sg.id
LEFT JOIN step_signals ss
    ON ss.step_id = s.id
ORDER BY
    w.created_at DESC,
    sg.group_idx ASC,
    s.idx ASC
) t;
SQL

echo "[query workflow steps] running query (limit=$limit workflow_id=${workflow_id:-<all>})"
rows_json=$(kubectl --namespace=ctl-api exec -i "$pod" -- \
  env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$db_user" "PGPASSWORD=$db_token" "PGSSLMODE=require" \
  psql --no-psqlrc -d "$db_name" -A -t -q -c "$sql" \
  | tr -d '\r' | { grep -E '^\[' || true; } | tail -n 1)

echo "[query workflow steps] scale down ctl-api-init"
kubectl scale -n ctl-api --current-replicas=1 --replicas=0 deployment/ctl-api-init

if [[ -z "$rows_json" ]]; then
  rows_json='[]'
fi

# Validate JSON; fail loud if psql returned something unparseable.
echo "$rows_json" | jq . > /dev/null

echo "[query workflow steps] $(echo "$rows_json" | jq 'length') rows returned"

if [[ -n "${NUON_ACTIONS_OUTPUT_FILEPATH:-}" ]]; then
  echo "[query workflow steps] writing outputs to $NUON_ACTIONS_OUTPUT_FILEPATH"
  # Pipe via stdin (not --argjson) to avoid "Argument list too long";
  # emit compact JSON so the runner's outputs parser sees a single
  # NDJSON line.
  printf '%s' "$rows_json" | jq -c '{rows: .}' > "$NUON_ACTIONS_OUTPUT_FILEPATH"
fi

echo "[query workflow steps] done"
