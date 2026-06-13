#!/usr/bin/env bash
set -euo pipefail

SERVICES="temporal-frontend temporal-history temporal-matching temporal-worker"

for svc in $SERVICES; do
  echo "scaling ${svc} to ${SCALE_TARGET} replicas"
  kubectl -n temporal scale deployment "${svc}" --replicas="${SCALE_TARGET}" || echo "warning: failed to scale ${svc}"
done

echo ""
echo "waiting for rollouts"
for svc in $SERVICES; do
  kubectl -n temporal rollout status deployment "${svc}" --timeout=180s || echo "warning: ${svc} rollout did not complete"
done

echo ""
echo "current state:"
kubectl -n temporal get deployments -o wide
