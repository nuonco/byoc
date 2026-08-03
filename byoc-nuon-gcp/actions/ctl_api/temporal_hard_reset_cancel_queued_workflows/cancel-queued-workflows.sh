#!/usr/bin/env bash
#
# Cancel every install_workflows row whose composite status is "queued" by
# updating status->'status' to "cancelled" and appending the prior status to
# the history array.
#
# Env vars (with defaults from the action toml):
#   DB_NAME     defaults to "ctl_api"
#   DB_PORT     defaults to "5432"
#   DB_ADDR     Cloud SQL endpoint (required)

set -e
set -o pipefail
set -u

db_name="${DB_NAME:-ctl_api}"
db_port="${DB_PORT:-5432}"
db_addr="$DB_ADDR"

echo "[cancel-queued-workflows] kubectl auth whoami"
kubectl auth whoami -o json | jq -c

# Update as the ctl-api IAM role (the table owner) via Cloud SQL IAM auth. The
# nuon-db admin user is NOT the owner and gets "permission denied". Impersonate
# the ctl-api SA on the runner (ctl_api_wi grants the runner token-creator on it)
# to mint a sqlservice.login-scoped token, used as the DB password over SSL.
: "${DB_USER:?DB_USER is required (ctl_api_wi.db_user, the IAM database user)}"
: "${CTL_API_SA_EMAIL:?CTL_API_SA_EMAIL is required (ctl_api_wi.service_account_email)}"
echo "[cancel-queued-workflows] minting a Cloud SQL login token as ${CTL_API_SA_EMAIL}"
db_token=$(gcloud auth print-access-token \
  --impersonate-service-account="$CTL_API_SA_EMAIL" \
  --scopes=https://www.googleapis.com/auth/sqlservice.login)
if [[ -z "$db_token" ]]; then
  echo "[cancel-queued-workflows] ERROR: failed to mint a login token as $CTL_API_SA_EMAIL." >&2
  exit 1
fi

# One-shot psql jump pod, stamped out of the suspended CronJob template that
# the ctl-api-init chart deploys. Each run gets its own job so concurrent
# actions can never grab each other's pods.
suffix="$(head -c 64 /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 5)"
job_name="ctl-api-cancel-queued-workflows-$(date -u +%Y%m%d-%H%M%S)-${suffix}"

cleanup() {
  kubectl delete job -n ctl-api "$job_name" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}
# the job template's sleep/activeDeadlineSeconds/ttlSecondsAfterFinished
# backstops reap the job if the runner dies before this fires
trap cleanup EXIT

echo "[cancel-queued-workflows] creating job $job_name"
kubectl create job -n ctl-api "$job_name" --from=cronjob/ctl-api-psql
kubectl annotate job -n ctl-api "$job_name" --overwrite \
  "nuon.co/action=ctl-api-cancel-queued-workflows" \
  "nuon.co/install-id=${NUON_INSTALL_ID:-unknown}" \
  "nuon.co/runner-id=${RUNNER_ID:-unknown}"

echo "[cancel-queued-workflows] waiting for the job pod"
# the job controller creates the pod asynchronously: poll for the object
# first, then wait for readiness (a cold node pool can take minutes)
pod=""
for _ in $(seq 1 30); do
  pod=$(kubectl get pods -n ctl-api -l "job-name=${job_name}" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null) && [ -n "$pod" ] && break
  sleep 2
done
if [[ -z "$pod" ]]; then
  echo "[cancel-queued-workflows] ERROR: job pod never appeared" >&2
  kubectl describe job -n ctl-api "$job_name" >&2 || true
  exit 1
fi
if ! kubectl wait -n ctl-api "pod/${pod}" --for=condition=Ready --timeout=300s; then
  kubectl describe pod -n ctl-api "$pod" >&2 || true
  exit 1
fi
echo "[cancel-queued-workflows] using pod: $pod"

sql="
WITH targets AS (
  SELECT id, status FROM install_workflows
  WHERE deleted_at = 0
    AND status->>'status' = 'queued'
)
UPDATE install_workflows w
SET status = jsonb_set(
  jsonb_set(
    jsonb_set(w.status,
      '{status}', '\"cancelled\"'::jsonb),
    '{status_human_description}', '\"cancelled by temporal_hard_reset SoP\"'::jsonb),
  '{history}',
    COALESCE(w.status->'history', '[]'::jsonb) || jsonb_build_array(t.status - 'history')
)
FROM targets t
WHERE w.id = t.id
RETURNING w.id;
"

echo "[cancel-queued-workflows] running update"
kubectl --namespace=ctl-api exec -i "$pod" -- \
  env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$DB_USER" "PGPASSWORD=$db_token" "PGSSLMODE=require" \
  psql --no-psqlrc -d "$db_name" -c "$sql"

echo "[cancel-queued-workflows] done (job cleaned up by the EXIT trap)"
