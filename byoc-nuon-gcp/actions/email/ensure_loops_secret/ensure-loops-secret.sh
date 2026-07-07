#!/usr/bin/env bash
#
# ensure-loops-secret (GCP)
#
# ctl-api's LOOPS_API_KEY config is required at boot (services/ctl-api
# validates it as non-empty), but Loops is no longer an app secret with a
# Terraform-managed "dne" default — sync_loops_secret writes the real value
# directly to k8s, out-of-band. This pre-deploy-component hook guarantees the
# ctl-api-loops-api-key secret exists (with a "dne" placeholder) the first
# time ctl_api deploys, and is a no-op on every redeploy after that, so a
# real, previously-synced value is never clobbered.
#
# Required env:
#   NAMESPACE - k8s namespace for ctl-api (default ctl-api).
set -euo pipefail
set -o errtrace

: "${NAMESPACE:=ctl-api}"

# pre-deploy-component hooks can run moments after the cluster reports ready,
# before the API server's networking has fully settled — poll instead of
# failing on the first transient timeout.
wait_for_apiserver() {
  attempts=24
  i=1
  while true; do
    if kubectl get --raw='/healthz' --request-timeout=10s >/dev/null 2>&1; then
      echo "[ensure_loops_secret] API server reachable (attempt ${i})."
      return 0
    fi
    if [ "$i" -ge "$attempts" ]; then
      echo "[ensure_loops_secret] ERROR: API server not reachable after ${attempts} attempts (~4m)." >&2
      kubectl get --raw='/healthz' --request-timeout=10s || true
      return 1
    fi
    i=$((i + 1))
    sleep 10
  done
}
wait_for_apiserver

if kubectl get secret ctl-api-loops-api-key -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "ctl-api-loops-api-key already exists in $NAMESPACE; nothing to do."
  exit 0
fi

echo "ctl-api-loops-api-key not found in $NAMESPACE; creating placeholder."
kubectl create secret generic ctl-api-loops-api-key \
  -n "$NAMESPACE" \
  --from-literal=value=dne

echo "done"
