#!/usr/bin/env bash
set -euo pipefail

NAMESPACES="orgs actions apps components installs releases general runners vcs emitters"

for ns in $NAMESPACES; do
  deploy="ctl-api-worker-${ns}"
  echo "scaling ${deploy} to ${SCALE_TARGET} replicas"
  kubectl -n ctl-api scale deployment "${deploy}" --replicas="${SCALE_TARGET}" || echo "warning: failed to scale ${deploy}"
done

echo ""
echo "current state:"
kubectl -n ctl-api get deployments -l app.kubernetes.io/component=worker -o wide
