#!/usr/bin/env bash

set -e
set -o pipefail
set -u

pg_host="$PGHOST"
pg_port="$PGPORT"
wi_user="$WI_USER"

# Run a kubectl command, retrying ONLY on transient GKE control-plane
# connectivity errors. The public API endpoint can drop a connection
# mid-deploy (endpoint warm-up, brief LB/SNAT reconvergence), so any single
# kubectl call can i/o-timeout. Real errors (auth failures, psql errors,
# missing resources) don't match the connectivity patterns, so they fail fast
# on the first attempt and are never masked.
kubectl_retry() {
  attempts=5
  i=1
  while true; do
    out=$(kubectl "$@" 2>&1) && { printf '%s\n' "$out"; return 0; }
    status=$?
    case "$out" in
      *"Unable to connect to the server"* | *"i/o timeout"* | *"dial tcp"* | \
      *"TLS handshake timeout"* | *"connection refused"* | *"unexpected EOF"* | \
      *"http2: client connection lost"* | *"EOF"*)
        if [ "$i" -ge "$attempts" ]; then
          printf '%s\n' "$out" >&2
          echo "[ctl-api-grant-wi] ERROR: 'kubectl $*' failed after ${attempts} attempts (transient API-server connectivity)." >&2
          return "$status"
        fi
        echo "[ctl-api-grant-wi] transient API-server error on 'kubectl $*' (attempt ${i}/${attempts}), retrying in 5s..." >&2
        i=$((i + 1))
        sleep 5
        ;;
      *)
        printf '%s\n' "$out" >&2
        return "$status"
        ;;
    esac
  done
}

# One-shot psql jump pod, stamped out of the suspended CronJob template that
# the ctl-api-init chart deploys. Each run gets its own job so back-to-back
# actions can never grab each other's pods (the old shared-deployment race).
suffix="$(head -c 64 /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 5)"
job_name="ctl-api-grant-wi-$(date -u +%Y%m%d-%H%M%S)-${suffix}"

cleanup() {
  kubectl delete job -n ctl-api "$job_name" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}
# the job template's sleep/activeDeadlineSeconds/ttlSecondsAfterFinished
# backstops reap the job if the runner dies before this fires
trap cleanup EXIT

echo "[ctl-api-grant-wi] creating job $job_name"
# a retried create can land after a first attempt already reached the server,
# so on failure re-check whether the job exists before giving up
if ! kubectl_retry create job -n ctl-api "$job_name" --from=cronjob/ctl-api-psql; then
  kubectl_retry get job -n ctl-api "$job_name" >/dev/null
fi

# no action-run/workflow id is exposed to action steps, so attribute the job
# with what the runner env does provide
kubectl_retry annotate job -n ctl-api "$job_name" --overwrite \
  "nuon.co/action=ctl-api-grant-wi" \
  "nuon.co/install-id=${NUON_INSTALL_ID:-unknown}" \
  "nuon.co/runner-id=${RUNNER_ID:-unknown}"

echo "[ctl-api-grant-wi] waiting for the job pod"
# the job controller creates the pod asynchronously: poll for the object
# first, then wait for readiness (a cold node pool can take minutes)
pod=""
for _ in $(seq 1 30); do
  pod=$(kubectl get pods -n ctl-api -l "job-name=${job_name}" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null) && [ -n "$pod" ] && break
  sleep 2
done
if [ -z "$pod" ]; then
  echo "[ctl-api-grant-wi] ERROR: job pod never appeared" >&2
  kubectl describe job -n ctl-api "$job_name" >&2 || true
  exit 1
fi
if ! kubectl_retry wait -n ctl-api "pod/${pod}" --for=condition=Ready --timeout=300s; then
  kubectl describe pod -n ctl-api "$pod" >&2 || true
  exit 1
fi
echo "[ctl-api-grant-wi] using pod: $pod"

echo "[ctl-api-grant-wi] reading db access secrets from k8s"
pg_user=$(kubectl_retry get -n ctl-api secret nuon-db -o jsonpath='{.data.username}' | base64 -d)
pg_password=$(kubectl_retry get -n ctl-api secret nuon-db -o jsonpath='{.data.password}' | base64 -d)

echo "[ctl-api-grant-wi] granting ctl_api role to $wi_user"
kubectl_retry --namespace=ctl-api exec -i "$pod" -- \
  env "PGHOST=$pg_host" "PGPORT=$pg_port" "PGUSER=$pg_user" "PGPASSWORD=$pg_password" \
  psql --no-psqlrc -d ctl_api -c "GRANT ctl_api TO \"${wi_user}\";"

echo "[ctl-api-grant-wi] done"
