#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="temporal"

echo "discovering all deployments in the ${NAMESPACE} namespace"

deployments=$(kubectl -n "${NAMESPACE}" get deployments -o jsonpath='{.items[*].metadata.name}')

if [ -z "${deployments}" ]; then
  echo "no deployments found in the ${NAMESPACE} namespace"
  exit 0
fi

for deploy in ${deployments}; do
  echo "scaling ${NAMESPACE}/${deploy} to ${SCALE_TARGET} replicas"
  kubectl -n "${NAMESPACE}" scale deployment "${deploy}" --replicas="${SCALE_TARGET}" \
    || echo "warning: failed to scale ${NAMESPACE}/${deploy}"
done

echo ""
echo "current state:"
kubectl -n "${NAMESPACE}" get deployments -o wide
