#!/usr/bin/env bash
set -euo pipefail

echo "discovering ctl-api-worker* deployments across all namespaces"

# find every deployment whose name starts with ctl-api-worker, in any namespace
deployments=$(kubectl get deployments --all-namespaces \
  -o jsonpath='{range .items[?(@.metadata.name)]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' \
  | awk '$2 ~ /^ctl-api-worker/ {print $1" "$2}')

if [ -z "${deployments}" ]; then
  echo "no ctl-api-worker* deployments found"
  exit 0
fi

while read -r ns deploy; do
  [ -z "${ns}" ] && continue
  echo "scaling ${ns}/${deploy} to ${SCALE_TARGET} replicas"
  kubectl -n "${ns}" scale deployment "${deploy}" --replicas="${SCALE_TARGET}" \
    || echo "warning: failed to scale ${ns}/${deploy}"
done <<< "${deployments}"

echo ""
echo "current state:"
kubectl get deployments --all-namespaces -o wide \
  | awk 'NR==1 || $2 ~ /^ctl-api-worker/'
