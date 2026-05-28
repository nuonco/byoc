#!/usr/bin/env bash

# scale deployments in a namespace to a target replica count.
# env:
#   REPLICAS  - target replica count (default: 1)
#   NAMESPACE - namespace to target (default: ctl-api)
#   FILTER    - optional grep filter applied to deployment names

set -euo pipefail

: "${REPLICAS:=1}"
: "${NAMESPACE:=ctl-api}"

echo "namespace=${NAMESPACE} replicas=${REPLICAS} filter=${FILTER:-<none>}"

deployments=$(kubectl -n "${NAMESPACE}" get deployment -o name)

if [ -n "${FILTER:-}" ]; then
  deployments=$(echo "${deployments}" | grep -- "${FILTER}" || true)
fi

if [ -z "${deployments}" ]; then
  echo "no deployments matched"
  exit 0
fi

echo "${deployments}" | while read -r deploy; do
  [ -z "${deploy}" ] && continue
  echo "scaling ${deploy} to ${REPLICAS} replicas"
  kubectl -n "${NAMESPACE}" scale "${deploy}" --replicas="${REPLICAS}" || echo "warning: failed to scale ${deploy}"
done

echo "current state:"
kubectl -n "${NAMESPACE}" get deployments -o wide
