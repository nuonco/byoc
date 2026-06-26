#!/usr/bin/env bash

set -e
set -o pipefail
set -u

# Probes the cluster for Helm release storage objects so we can see whether a
# given component (e.g. karpenter_nodepools) actually has a recorded Helm
# release, in which namespace, and with what status. Components using the
# "configmap"/"secrets" storage driver keep their release history as
# ConfigMaps/Secrets in the release namespace (labeled owner=helm). A teardown
# that reports "no prior release" means nothing here matched the release name +
# namespace it looked up.
#
# Optional env:
#   RELEASE_FILTER  substring to highlight (default "karpenter")
#
# Requires cluster access (KUBECONFIG), which Nuon provides to the action when
# the install has cluster access enabled.

filter="${RELEASE_FILTER:-karpenter}"

: "${KUBECONFIG:?KUBECONFIG not set — enable cluster access for this install}"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: kubectl not found on PATH" >&2
  exit 1
fi

cols='NAMESPACE:.metadata.namespace,RELEASE:.metadata.labels.name,REV:.metadata.labels.version,STATUS:.metadata.labels.status,UPDATED:.metadata.creationTimestamp'

echo "==================================================================="
echo " Helm release storage probe (filter: ${filter})"
echo "==================================================================="

echo ""
echo "== All Helm release ConfigMaps (owner=helm), every namespace =="
kubectl get configmaps -A -l owner=helm -o custom-columns="$cols" 2>/dev/null \
  || echo "(none, or unable to list configmaps)"

echo ""
echo "== All Helm release Secrets (owner=helm), every namespace =="
kubectl get secrets -A -l owner=helm -o custom-columns="$cols" 2>/dev/null \
  || echo "(none, or unable to list secrets)"

echo ""
echo "== Matches for '${filter}' =="
matches=$(kubectl get configmaps,secrets -A -l owner=helm \
  -o custom-columns="$cols" 2>/dev/null | grep -i "$filter" || true)
if [ -n "$matches" ]; then
  echo "$matches"
else
  echo "No Helm release objects matching '${filter}' — i.e. no recorded release."
  echo "That is exactly the 'no prior release' condition the teardown hit."
fi

echo ""
echo "Compare the NAMESPACE + RELEASE above against what the karpenter_nodepools"
echo "teardown plan looked up (its release name + namespace). A mismatch there is"
echo "why prevRel was nil; an empty list means the release was never stored or was"
echo "already removed."
