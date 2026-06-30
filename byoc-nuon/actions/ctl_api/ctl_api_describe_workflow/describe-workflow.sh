#!/usr/bin/env bash
#
# Describe a single nuon (install) workflow.
#
# Given a WORKFLOW_ID (an install_workflows.id), this loads the workflow row
# (joined with org + created-by account) and its steps (ordered by group/step
# idx) and emits one JSON object: { workflow, steps, ... }. Each status
# `history` array is trimmed to its 10 most recent entries.
#
# Env vars (DB connection comes from the sandbox/component outputs via the
# action toml, same as ctl_api_query_db):
#   WORKFLOW_ID (required) install_workflows.id (26-char ULID-style id)
#   DB_USER     (required) master username (sanity-checked against the secret)
#   SECRET_ARN  (required) master-user secret ARN
#   DB_ADDR     (required) RDS endpoint
#   REGION      (required) AWS region
#   DB_NAME     (optional) defaults to "ctl_api"
#   DB_PORT     (optional) defaults to "5432"

set -e
set -o pipefail
set -u

workflow_id="$WORKFLOW_ID"
db_user="$DB_USER"
db_addr="$DB_ADDR"
db_port="${DB_PORT:-5432}"
db_name="${DB_NAME:-ctl_api}"
region="$REGION"
secret_arn="$SECRET_ARN"

if [[ -z "$workflow_id" ]]; then
  echo "[describe workflow] ERROR: WORKFLOW_ID is required" >&2
  exit 1
fi
# ids are 26-char base32 ULIDs (see install_workflows.id_checker). Validating
# the format also keeps the value safe to interpolate into the SQL below.
if ! [[ "$workflow_id" =~ ^[a-zA-Z0-9]{26}$ ]]; then
  echo "[describe workflow] ERROR: WORKFLOW_ID must be a 26-char id, got: $workflow_id" >&2
  exit 1
fi

echo "[describe workflow] kubectl auth whoami"
kubectl auth whoami -o json | jq -c

echo "[describe workflow] db_addr=$db_addr region=$region workflow_id=$workflow_id"

echo "[describe workflow] loading db credentials"
secret=$(aws --region "$region" secretsmanager get-secret-value --secret-id="$secret_arn")
admin_username=$(echo "$secret" | jq -r '.SecretString' | jq -r '.username')
admin_password=$(echo "$secret" | jq -r '.SecretString' | jq -r '.password')

echo "[describe workflow] sanity check (these should match)"
echo "db_user=$db_user"
echo "username=$admin_username"

echo "[describe workflow] scale up ctl-api-init"
kubectl scale -n ctl-api --replicas=1 deployment/ctl-api-init
kubectl wait deployment -n ctl-api ctl-api-init --for condition=Available=True --timeout=300s

pod=$(kubectl -n ctl-api get pods --selector app=ctl-api-init -o json | jq -r '.items[0].metadata.name')
echo "[describe workflow] using pod: $pod"

# $workflow_id is validated as ^[a-zA-Z0-9]{26}$ above, so it is safe to inline.
sql="
SET default_transaction_read_only = on;
WITH wf AS (
  SELECT * FROM install_workflows WHERE id = '$workflow_id'
),
steps AS (
  SELECT * FROM install_workflow_steps WHERE install_workflow_id = '$workflow_id'
)
SELECT json_build_object(
  'workflow_id', '$workflow_id',
  'found', (SELECT count(*) FROM wf) > 0,
  'workflow', (
    SELECT to_jsonb(w)
           || jsonb_build_object(
                'metadata',         hstore_to_json(w.metadata),
                'org_name',         o.name,
                'created_by_email', a.email)
    FROM wf w
    LEFT JOIN orgs     o ON o.id = w.org_id
    LEFT JOIN accounts a ON a.id = w.created_by_id
  ),
  'step_count', (SELECT count(*) FROM steps),
  'steps', (
    SELECT COALESCE(jsonb_agg(
             to_jsonb(s) || jsonb_build_object('metadata', hstore_to_json(s.metadata))
             ORDER BY s.group_idx, s.idx), '[]'::jsonb)
    FROM steps s
  )
)::text;
"

echo "[describe workflow] running query"
result_json=$(kubectl --namespace=ctl-api exec -i "$pod" -- \
  env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$admin_username" "PGPASSWORD=$admin_password" \
  psql --no-psqlrc -d "$db_name" -A -t -q -c "$sql" \
  | tr -d '\r' | { grep -E '^[[\{]' || true; } | tail -n 1)

echo "[describe workflow] scale down ctl-api-init"
kubectl scale -n ctl-api --current-replicas=1 --replicas=0 deployment/ctl-api-init

if [[ -z "$result_json" ]]; then
  echo "[describe workflow] ERROR: query returned no rows" >&2
  exit 1
fi

# Validate it's parseable JSON; fail loud if not.
echo "$result_json" | jq . > /dev/null

# Trim every status `history` array to its 10 most recent entries -- these can
# grow to hundreds of entries and dominate the output. Annotate trimmed arrays
# with the original length so it's clear data was dropped.
result_json=$(echo "$result_json" | jq -c '
  walk(
    if type == "object" and (.history | type) == "array" and (.history | length) > 10
    then .history_total = (.history | length) | .history |= .[-10:]
    else . end
  )')

found=$(echo "$result_json" | jq -r '.found')
if [[ "$found" != "true" ]]; then
  echo "[describe workflow] WARNING: no workflow found with id $workflow_id" >&2
fi

echo "[describe workflow] summary:" >&2
echo "$result_json" | jq -r '
  "  found=\(.found) type=\(.workflow.type // "-") name=\(.workflow.name // "-") steps=\(.step_count)"' >&2

# Pretty-print the full object to the logs.
echo "$result_json" | jq .

if [[ -n "${NUON_ACTIONS_OUTPUT_FILEPATH:-}" ]]; then
  echo "[describe workflow] writing outputs"
  echo "$result_json" > "$NUON_ACTIONS_OUTPUT_FILEPATH"
fi

echo "[describe workflow] done"
