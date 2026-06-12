#!/usr/bin/env bash
#
# Monitor ctl-api install_workflows for errors. Uses $SINCE_TS (the previous
# run's DB-side cursor, threaded in via templated env var) as the lower bound
# when present; otherwise falls back to NOW() - $SINCE_MINUTES (default 10,
# matching the cron cadence). Filters to status='error' in SQL so only error
# rows cross the wire. Caps at $LIMIT rows. Fails non-zero if any errors found.

set -e
set -o pipefail
set -u

db_name="${DB_NAME:-ctl_api}"
db_user="$DB_USER"
db_addr="$DB_ADDR"
db_port="${DB_PORT:-5432}"
region="$REGION"
secret_arn="$SECRET_ARN"
since_minutes="${SINCE_MINUTES:-10}"
since_ts="${SINCE_TS:-}"
# Template engine HTML-escapes '+' (and possibly other chars) when interpolating
# the prior run's cursor back into env vars. Decode the common ones.
since_ts="${since_ts//&#43;/+}"
since_ts="${since_ts//&amp;/&}"
limit="${LIMIT:-100}"

if ! [[ "$since_minutes" =~ ^[0-9]+$ ]]; then
  echo "[monitor workflows] ERROR: SINCE_MINUTES must be an integer, got: $since_minutes" >&2
  exit 1
fi

if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
  echo "[monitor workflows] ERROR: LIMIT must be an integer, got: $limit" >&2
  exit 1
fi

if [[ -n "$since_ts" ]] && ! [[ "$since_ts" =~ ^[0-9T:.Z+-]+$ ]]; then
  echo "[monitor workflows] ERROR: SINCE_TS not an ISO8601-looking timestamp: $since_ts" >&2
  exit 1
fi

if [[ -n "$since_ts" ]]; then
  since_clause="w.updated_at >= '${since_ts}'::timestamptz"
  echo "[monitor workflows] using SINCE_TS=$since_ts (from prior run)"
else
  since_clause="w.updated_at >= NOW() - INTERVAL '${since_minutes} minutes'"
  echo "[monitor workflows] no SINCE_TS; falling back to last $since_minutes minutes"
fi

echo "[monitor workflows] kubectl auth whoami"
kubectl auth whoami -o json | jq -c

echo "[monitor workflows] scale up ctl-api-init"
kubectl scale -n ctl-api --replicas=1 deployment/ctl-api-init
kubectl wait deployment -n ctl-api ctl-api-init --for condition=Available=True --timeout=300s

pod=$(kubectl -n ctl-api get pods --selector app=ctl-api-init --field-selector=status.phase=Running -o json \
  | jq -r '[.items[] | select(.metadata.deletionTimestamp == null)] | sort_by(.metadata.creationTimestamp) | last | .metadata.name')
if [[ -z "$pod" || "$pod" == "null" ]]; then
  echo "[monitor workflows] ERROR: no running ctl-api-init pod found" >&2
  exit 1
fi
echo "[monitor workflows] using pod: $pod"

echo "[monitor workflows] reading db credentials from AWS"
secret=$(aws --region "$region" secretsmanager get-secret-value --secret-id="$secret_arn")
admin_username=$(echo "$secret" | jq -r '.SecretString' | jq -r '.username')
admin_password=$(echo "$secret" | jq -r '.SecretString' | jq -r '.password')

# Single statement: stamp the cursor from the DB clock (avoids runner/DB skew)
# and aggregate the error rows in one round-trip. Filter status='error' in SQL
# so a quiet window returns zero rows. Limit caps worst-case payload.
read -r -d '' sql <<SQL || true
SET default_transaction_read_only = on;
SELECT json_build_object(
  'cursor', to_char(clock_timestamp() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
  'status_counts', COALESCE((
    SELECT json_object_agg(s, c) FROM (
      SELECT w.status->>'status' AS s, COUNT(*) AS c
      FROM install_workflows w
      WHERE w.deleted_at = 0
        AND ${since_clause}
      GROUP BY w.status->>'status'
    ) g
  ), '{}'::json),
  'errors', COALESCE((
    SELECT json_agg(row_to_json(t) ORDER BY t.updated_at DESC)
    FROM (
      SELECT w.id                AS workflow_id,
             w.type              AS workflow_type,
             w.status->>'status' AS workflow_status,
             w.started_at        AS started_at,
             w.finished_at       AS finished_at,
             w.updated_at        AS updated_at,
             w.created_by_id     AS created_by_id,
             w.org_id            AS org_id,
             w.owner_id          AS install_id,
             w.metadata->'workflow-name-suffix'         AS workflow_name_suffix,
             w.metadata->'install_action_workflow_name' AS install_action_workflow_name
      FROM install_workflows w
      WHERE w.deleted_at = 0
        AND w.status->>'status' NOT IN ('queued', 'running', 'finished', 'success', 'cancelled', 'canceled')
        AND ${since_clause}
      ORDER BY w.updated_at DESC
      LIMIT ${limit}
    ) t
  ), '[]'::json)
)::text;
SQL

echo "[monitor workflows] running query (since_clause=$since_clause, limit=$limit)"
result_json=$(kubectl --namespace=ctl-api exec -i "$pod" -- \
  env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$admin_username" "PGPASSWORD=$admin_password" \
  psql --no-psqlrc -d "$db_name" -A -t -q -c "$sql" \
  | tr -d '\r' | { grep -E '^\{' || true; } | tail -n 1)

echo "[monitor workflows] scale down ctl-api-init"
kubectl scale -n ctl-api --current-replicas=1 --replicas=0 deployment/ctl-api-init

if [[ -z "$result_json" ]]; then
  echo "[monitor workflows] ERROR: empty result from query" >&2
  exit 1
fi

echo "$result_json" | jq . > /dev/null

cursor=$(echo "$result_json" | jq -r '.cursor')
errors_json=$(echo "$result_json" | jq -c '.errors')
status_counts=$(echo "$result_json" | jq -c '.status_counts')
error_count=$(echo "$errors_json" | jq 'length')

echo "[monitor workflows] cursor=$cursor"
echo "[monitor workflows] status_counts=$status_counts"
echo "[monitor workflows] error_count=$error_count"

if [[ -n "${NUON_ACTIONS_OUTPUT_FILEPATH:-}" ]]; then
  jq -cn \
    --arg ts "$cursor" \
    --argjson errs "$errors_json" \
    --argjson errc "$error_count" \
    --argjson counts "$status_counts" \
    '{updated_at: $ts, error_count: $errc, status_counts: $counts, errors: $errs}' \
    > "$NUON_ACTIONS_OUTPUT_FILEPATH"
fi

if [[ "$error_count" -gt 0 ]]; then
  echo "[monitor workflows] FAIL: $error_count workflow(s) with status=error" >&2
  echo "$errors_json" | jq -r '.[] | "  - \(.workflow_id) type=\(.workflow_type) by=\(.created_by_id) org=\(.org_id) install=\(.install_id) started=\(.started_at) finished=\(.finished_at)"' >&2
  exit 1
fi

echo "[monitor workflows] done"
