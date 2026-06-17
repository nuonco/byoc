#!/usr/bin/env bash
#
# Query ctl-api for one (or the most recent) component build, with enough
# detail to debug a stuck or failed build: the de-nested component, the
# resolved image source fields, the status_v2 history, and the build's
# polymorphic runner job + log stream.
#
# component_builds notes (see ctl-api internal/app/component_build.go):
#   - component_id / component_name are de-nested from the build's
#     component_config_connection; they are not columns on component_builds.
#   - status is two-headed (string `status` + jsonb `status_v2`); we COALESCE
#     status_v2->>'status' over the legacy column, matching ctl-api AfterQuery.
#   - runner_jobs / log_streams attach polymorphically with
#     owner_type = 'component_builds' (gorm default = owner table name).
#
# Env vars:
#   BUILD_ID    (optional)  ctl-api build id to inspect; if unset, the most
#                           recent build is returned
#   LIMIT       (optional)  max builds when BUILD_ID is unset; defaults to 1
#   DB_NAME / DB_PORT / DB_ADDR / SECRET_ARN / REGION  (see query-builds.sh)

set -e
set -o pipefail
set -u

db_name="$DB_NAME"
db_user="$DB_USER"
db_addr="$DB_ADDR"
db_port="$DB_PORT"
region="$REGION"
secret_arn="$SECRET_ARN"
limit="${LIMIT:-1}"
build_id="${BUILD_ID:-}"

if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
  echo "[query build] ERROR: LIMIT must be an integer, got: $limit" >&2
  exit 1
fi

# BUILD_ID is an opaque ctl-api id. Enforce a conservative charset so it can be
# safely interpolated into the SQL below.
if [[ -n "$build_id" ]] && ! [[ "$build_id" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "[query build] ERROR: BUILD_ID contains unexpected characters: $build_id" >&2
  exit 1
fi

if [[ -n "$build_id" ]]; then
  build_filter="AND b.id = '$build_id'"
else
  build_filter=""
fi

echo "[query build] kubectl auth whoami"
kubectl auth whoami -o json | jq -c

# Ensure ctl-api-init is scaled back down even if the query fails partway
# through (set -e would otherwise skip the explicit scale-down below and leave
# a DB-access pod running). The flag keeps the trap a no-op until we scale up.
scaled_up=0
cleanup() {
  if [[ "$scaled_up" == "1" ]]; then
    echo "[query build] cleanup: scaling down ctl-api-init"
    kubectl scale -n ctl-api --replicas=0 deployment/ctl-api-init >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

echo "[query build] scale up ctl-api-init"
kubectl scale -n ctl-api --replicas=1 deployment/ctl-api-init
scaled_up=1
kubectl wait deployment -n ctl-api ctl-api-init --for condition=Available=True --timeout=300s

pod=$(kubectl -n ctl-api get pods --selector app=ctl-api-init --field-selector=status.phase=Running -o json \
  | jq -r '[.items[] | select(.metadata.deletionTimestamp == null)] | sort_by(.metadata.creationTimestamp) | last | .metadata.name')
if [[ -z "$pod" || "$pod" == "null" ]]; then
  echo "[query build] ERROR: no running ctl-api-init pod found" >&2
  exit 1
fi
echo "[query build] using pod: $pod"

echo "[query build] reading db access secrets from AWS"
secret=$(aws --region "$region" secretsmanager get-secret-value --secret-id="$secret_arn")
admin_username=$(echo "$secret" | jq -r '.SecretString' | jq -r '.username')
admin_password=$(echo "$secret" | jq -r '.SecretString' | jq -r '.password')

echo "[query build] sanity check"
echo "db_user=$db_user"
echo "username=$admin_username"

read -r -d '' sql <<SQL || true
SET default_transaction_read_only = on;
SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)::text FROM (
SELECT
    b.id                                                                              AS build_id,
    COALESCE(NULLIF(b.status_v2->>'status', ''), b.status)                            AS build_status,
    COALESCE(NULLIF(b.status_v2->>'status_human_description', ''), b.status_description) AS build_status_description,
    b.created_at        AS build_created_at,
    b.updated_at        AS build_updated_at,
    -- git_ref, checksum, no_op, vcs_connection_commit_id and the image-source
    -- fields were added with later ctl-api features and may not exist on older
    -- schemas. Read them through to_jsonb(b) so a missing column yields NULL
    -- rather than erroring the whole query.
    to_jsonb(b)->>'resolved_at'                       AS build_resolved_at,
    COALESCE((to_jsonb(b)->>'no_op')::boolean, false) AS build_no_op,
    to_jsonb(b)->>'git_ref'                           AS git_ref,
    to_jsonb(b)->>'checksum'                          AS checksum,
    to_jsonb(b)->>'source_ref'                        AS source_ref,
    to_jsonb(b)->>'source_image'                      AS source_image,
    to_jsonb(b)->>'resolved_tag'                      AS resolved_tag,
    to_jsonb(b)->>'source_digest'                     AS source_digest,
    to_jsonb(b)->>'source_media_type'                 AS source_media_type,
    b.component_config_connection_id AS component_config_connection_id,
    to_jsonb(b)->>'vcs_connection_commit_id'          AS vcs_connection_commit_id,

    b.org_id            AS org_id,
    o.name              AS org_name,
    b.created_by_id     AS created_by_id,
    a.email             AS created_by_email,
    a.subject           AS created_by_subject,
    a.account_type      AS created_by_account_type,

    ccc.component_id    AS component_id,
    c.name              AS component_name,
    c.type              AS component_type,

    -- build's runner job (polymorphic owner = component_builds)
    rj.id               AS runner_job_id,
    rj.status           AS runner_job_status,
    rj.runner_id        AS runner_id,
    rj.created_at       AS runner_job_created_at,
    rj.log_stream_id    AS log_stream_id,

    -- the runner job's resolved plan (runner_job_plans, keyed off the runner
    -- job; see the plan LATERAL join below)
    plan.runner_job_plan AS runner_job_plan,

    -- the component's build queue (queues.owner_id = component_id,
    -- owner_type = 'components')
    q.id                AS queue_id,
    q.name              AS queue_name,
    q.max_depth         AS queue_max_depth,
    q.max_in_flight     AS queue_max_in_flight,
    q.idle_timeout      AS queue_idle_timeout,
    q.queue_status      AS queue_status,
    q.queue_depth       AS queue_depth,

    -- this build's signal(s) on the queue (queue_signals.owner_id = build_id,
    -- owner_type = 'component_builds'), newest first
    sigs.signals        AS build_signals
FROM component_builds b
LEFT JOIN accounts a ON a.id = b.created_by_id
LEFT JOIN orgs     o ON o.id = b.org_id
LEFT JOIN component_config_connections ccc ON ccc.id = b.component_config_connection_id
LEFT JOIN components c ON c.id = ccc.component_id
LEFT JOIN LATERAL (
    SELECT j.id, j.status, j.runner_id, j.created_at, j.log_stream_id
    FROM runner_jobs j
    WHERE j.owner_type = 'component_builds'
      AND j.owner_id   = b.id
      AND j.deleted_at = 0
    ORDER BY j.created_at DESC
    LIMIT 1
) rj ON true
LEFT JOIN LATERAL (
    -- the runner job's resolved plan (runner_job_plans.runner_job_id = rj.id).
    -- ctl-api prefers the composite_plan jsonb and falls back to plan_json (the
    -- bare build plan); we surface the same composite envelope the dashboard
    -- shows ({ "build_plan": {...} }). Read through to_jsonb so a missing column
    -- on an older schema yields NULL rather than erroring the whole query.
    SELECT CASE
             WHEN COALESCE(to_jsonb(rjp)->'composite_plan', '{}'::jsonb)
                    NOT IN ('{}'::jsonb, 'null'::jsonb)
               THEN to_jsonb(rjp)->'composite_plan'
             WHEN COALESCE(to_jsonb(rjp)->>'plan_json', '') <> ''
               THEN jsonb_build_object('build_plan', (to_jsonb(rjp)->>'plan_json')::jsonb)
             ELSE NULL
           END AS runner_job_plan
    FROM runner_job_plans rjp
    WHERE rjp.runner_job_id = rj.id
      AND rjp.deleted_at = 0
    ORDER BY rjp.created_at DESC
    LIMIT 1
) plan ON true
LEFT JOIN LATERAL (
    SELECT q.id, q.name, q.max_depth, q.max_in_flight, q.idle_timeout,
           to_jsonb(q)->'status_v2'->>'status' AS queue_status,
           (SELECT count(*) FROM queue_signals d
              WHERE d.queue_id = q.id
                AND d.deleted_at = 0
                AND (d.status->>'status') IN ('queued', 'in_progress')) AS queue_depth
    FROM queues q
    WHERE q.owner_id   = ccc.component_id
      AND q.owner_type = 'components'
      AND q.deleted_at = 0
    ORDER BY q.created_at DESC
    LIMIT 1
) q ON true
LEFT JOIN LATERAL (
    SELECT COALESCE(jsonb_agg(s ORDER BY s.created_at DESC), '[]'::jsonb) AS signals
    FROM (
      SELECT qs.id,
             qs.type                                                        AS signal_type,
             qs.status->>'status'                                           AS signal_status,
             qs.status->>'status_human_description'                         AS signal_status_description,
             qs.enqueued,
             qs.execution_count,
             to_char(qs.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS') AS created_at,
             to_char(qs.expires_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS') AS expires_at,
             -- lifecycle timeline (queue_signals.status->'metadata', RFC3339):
             -- enqueue_started_at..execute_finished_at. Mirrors the admin
             -- "Timeline" card.
             qs.status->'metadata'->>'enqueue_started_at'  AS enqueue_started_at,
             qs.status->'metadata'->>'enqueue_finished_at' AS enqueue_finished_at,
             qs.status->'metadata'->>'dequeued_at'         AS dequeued_at,
             qs.status->'metadata'->>'execute_started_at'  AS execute_started_at,
             qs.status->'metadata'->>'execute_finished_at' AS execute_finished_at
      FROM queue_signals qs
      WHERE qs.owner_id   = b.id
        AND qs.owner_type = 'component_builds'
        AND qs.deleted_at = 0
    ) s
) sigs ON true
WHERE b.deleted_at = 0
  ${build_filter}
ORDER BY b.created_at DESC
LIMIT ${limit}
) t;
SQL

echo "[query build] running query (limit=$limit build_id=${build_id:-<latest>})"
rows_json=$(kubectl --namespace=ctl-api exec -i "$pod" -- \
  env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$admin_username" "PGPASSWORD=$admin_password" \
  psql --no-psqlrc -d "$db_name" -A -t -q -c "$sql" \
  | tr -d '\r' | { grep -E '^\[' || true; } | tail -n 1)

echo "[query build] scale down ctl-api-init"
kubectl scale -n ctl-api --current-replicas=1 --replicas=0 deployment/ctl-api-init
scaled_up=0

if [[ -z "$rows_json" ]]; then
  rows_json='[]'
fi

# Validate JSON; fail loud if psql returned something unparseable.
echo "$rows_json" | jq . > /dev/null

echo "[query build] $(echo "$rows_json" | jq 'length') rows returned"

if [[ -n "${NUON_ACTIONS_OUTPUT_FILEPATH:-}" ]]; then
  echo "[query build] writing outputs to $NUON_ACTIONS_OUTPUT_FILEPATH"
  printf '%s' "$rows_json" | jq -c '{rows: .}' > "$NUON_ACTIONS_OUTPUT_FILEPATH"
fi

echo "[query build] done"
