#!/usr/bin/env bash

set -e
set -o pipefail
set -u

db_name="$DB_NAME"
db_user="$DB_USER"
db_addr="$DB_ADDR"
db_port="$DB_PORT"
query="$QUERY"

# TODO: make the cluster's default/admin db and the ctl-api db distinct

echo "[ctl_api query] kubectl auth whoami"
echo "pwd: "`pwd`
kubectl auth whoami -o json | jq -c


# One-shot psql jump pod, stamped out of the suspended CronJob template that
# the ctl-api-init chart deploys. Each run gets its own job so concurrent
# actions can never grab each other's pods.
suffix="$(head -c 64 /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 5)"
job_name="ctl-api-query-db-$(date -u +%Y%m%d-%H%M%S)-${suffix}"

cleanup() {
  kubectl delete job -n ctl-api "$job_name" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}
# the job template's sleep/activeDeadlineSeconds/ttlSecondsAfterFinished
# backstops reap the job if the runner dies before this fires
trap cleanup EXIT

echo "[ctl_api query] creating job $job_name"
kubectl create job -n ctl-api "$job_name" --from=cronjob/ctl-api-psql
kubectl annotate job -n ctl-api "$job_name" --overwrite \
  "nuon.co/action=ctl-api-query-db" \
  "nuon.co/install-id=${NUON_INSTALL_ID:-unknown}" \
  "nuon.co/runner-id=${RUNNER_ID:-unknown}"

echo "[ctl_api query] waiting for the job pod"
# the job controller creates the pod asynchronously: poll for the object
# first, then wait for readiness (a cold node pool can take minutes)
pod=""
for _ in $(seq 1 30); do
  pod=$(kubectl get pods -n ctl-api -l "job-name=${job_name}" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null) && [ -n "$pod" ] && break
  sleep 2
done
if [[ -z "$pod" ]]; then
  echo "[ctl_api query] ERROR: job pod never appeared" >&2
  kubectl describe job -n ctl-api "$job_name" >&2 || true
  exit 1
fi
if ! kubectl wait -n ctl-api "pod/${pod}" --for=condition=Ready --timeout=300s; then
  kubectl describe pod -n ctl-api "$pod" >&2 || true
  exit 1
fi
echo "[ctl_api query] using pod: $pod"

# Query as the ctl-api IAM role (the table owner) via Cloud SQL IAM auth. The
# nuon-db admin user is NOT the owner and gets "permission denied". Impersonate
# the ctl-api SA on the runner (ctl_api_wi grants the runner token-creator on it)
# to mint a sqlservice.login-scoped token, used as the DB password over SSL.
: "${CTL_API_SA_EMAIL:?CTL_API_SA_EMAIL is required (ctl_api_wi.service_account_email)}"
echo "[ctl_api query] minting a Cloud SQL login token as ${CTL_API_SA_EMAIL}"
db_token=$(gcloud auth print-access-token \
  --impersonate-service-account="$CTL_API_SA_EMAIL" \
  --scopes=https://www.googleapis.com/auth/sqlservice.login)
if [[ -z "$db_token" ]]; then
  echo "[ctl_api query] ERROR: failed to mint a login token as $CTL_API_SA_EMAIL." >&2
  exit 1
fi

echo "[ctl_api query] preparing to initialize"
function execute_query() {
  echo " > query: $1"
  kubectl \
    --namespace=ctl-api \
    exec  -i \
    $pod -- \
    env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$db_user" "PGPASSWORD=$db_token" "PGSSLMODE=require" \
    psql --no-psqlrc -d "ctl_api" -c "SET default_transaction_read_only = on; $1"
}
# sleep so logs have time to flush?
sleep 1

execute_query "$query"

echo "[ctl_api query] done (job cleaned up by the EXIT trap)"
