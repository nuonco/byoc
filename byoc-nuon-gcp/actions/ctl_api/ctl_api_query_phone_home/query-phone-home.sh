#!/usr/bin/env bash
#
# Query phone-home state for an install and emit the results to the action's
# outputs file ($NUON_ACTIONS_OUTPUT_FILEPATH) so they appear in the UI's
# Outputs tab.
#
# The entire JSON envelope is constructed inside Postgres so we don't have to
# combine multiple psql outputs in shell (which is fragile with --argjson).

set -e
set -o pipefail
set -u

db_name="$DB_NAME"
db_user="$DB_USER"
db_addr="$DB_ADDR"
db_port="$DB_PORT"
install_id="$INSTALL_ID"

echo "[query phone-home] kubectl auth whoami"
kubectl auth whoami -o json | jq -c

# One-shot psql jump pod, stamped out of the suspended CronJob template that
# the ctl-api-init chart deploys. Each run gets its own job so concurrent
# actions can never grab each other's pods.
suffix="$(head -c 64 /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 5)"
job_name="ctl-api-query-phone-home-$(date -u +%Y%m%d-%H%M%S)-${suffix}"

cleanup() {
  kubectl delete job -n ctl-api "$job_name" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}
# the job template's sleep/activeDeadlineSeconds/ttlSecondsAfterFinished
# backstops reap the job if the runner dies before this fires
trap cleanup EXIT

echo "[query phone-home] creating job $job_name"
kubectl create job -n ctl-api "$job_name" --from=cronjob/ctl-api-psql
kubectl annotate job -n ctl-api "$job_name" --overwrite \
  "nuon.co/action=ctl-api-query-phone-home" \
  "nuon.co/install-id=${NUON_INSTALL_ID:-unknown}" \
  "nuon.co/runner-id=${RUNNER_ID:-unknown}"

echo "[query phone-home] waiting for the job pod"
# the job controller creates the pod asynchronously: poll for the object
# first, then wait for readiness (a cold node pool can take minutes)
pod=""
for _ in $(seq 1 30); do
  pod=$(kubectl get pods -n ctl-api -l "job-name=${job_name}" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null) && [ -n "$pod" ] && break
  sleep 2
done
if [[ -z "$pod" ]]; then
  echo "[query phone-home] ERROR: job pod never appeared" >&2
  kubectl describe job -n ctl-api "$job_name" >&2 || true
  exit 1
fi
if ! kubectl wait -n ctl-api "pod/${pod}" --for=condition=Ready --timeout=300s; then
  kubectl describe pod -n ctl-api "$pod" >&2 || true
  exit 1
fi
echo "[query phone-home] using pod: $pod"

# Query as the ctl-api IAM role (the table owner) via Cloud SQL IAM auth. The
# nuon-db admin user is NOT the owner and gets "permission denied". Impersonate
# the ctl-api SA on the runner (ctl_api_wi grants the runner token-creator on it)
# to mint a sqlservice.login-scoped token, used as the DB password over SSL.
: "${CTL_API_SA_EMAIL:?CTL_API_SA_EMAIL is required (ctl_api_wi.service_account_email)}"
echo "[query phone-home] minting a Cloud SQL login token as ${CTL_API_SA_EMAIL}"
db_token=$(gcloud auth print-access-token \
  --impersonate-service-account="$CTL_API_SA_EMAIL" \
  --scopes=https://www.googleapis.com/auth/sqlservice.login)
if [[ -z "$db_token" ]]; then
  echo "[query phone-home] ERROR: failed to mint a login token as $CTL_API_SA_EMAIL." >&2
  exit 1
fi

sql="
SET default_transaction_read_only = on;
SELECT json_build_object(
  'install_id', '$install_id',
  'stack_versions', (
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
    FROM (
      SELECT id, install_id, install_stack_id, phone_home_id, phone_home_url,
             status, created_at, updated_at
      FROM install_stack_versions
      WHERE install_id = '$install_id'
      ORDER BY created_at DESC
    ) t
  ),
  'runs', (
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
    FROM (
      SELECT r.id AS run_id,
             r.install_stack_version_id,
             r.created_at,
             hstore_to_json(r.data) AS data
      FROM install_stack_version_runs r
      JOIN install_stack_versions v ON v.id = r.install_stack_version_id
      WHERE v.install_id = '$install_id'
      ORDER BY r.created_at DESC
    ) t
  )
)::text;
"

echo "[query phone-home] running query"
output=$(kubectl --namespace=ctl-api exec -i "$pod" -- \
  env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$db_user" "PGPASSWORD=$db_token" "PGSSLMODE=require" \
  psql --no-psqlrc -d "$db_name" -A -t -c "$sql" | tr -d '\r' | grep -v '^$' | tail -n 1)

if [[ -z "$output" ]]; then
  echo "[query phone-home] ERROR: empty result from db" >&2
  exit 1
fi

# Validate JSON before writing so a malformed result fails the step loudly
# rather than silently corrupting outputs.
echo "$output" | jq . > /dev/null

echo "[query phone-home] writing outputs"
echo "$output" > "$NUON_ACTIONS_OUTPUT_FILEPATH"

echo "[query phone-home] preview:"
echo "$output" | jq .
