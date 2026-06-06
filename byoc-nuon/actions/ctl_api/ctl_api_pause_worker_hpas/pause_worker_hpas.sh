#!/usr/bin/env bash
#
# Pause ctl-api worker autoscaling so the worker deployments can be held at 0
# replicas during a temporal reset. Native (autoscaling/v2) HPAs have no pause
# switch and would immediately scale the deployments back up, so we:
#   1. back up every worker HPA into a configmap (idempotent — never clobbers an
#      existing backup)
#   2. delete the HPAs
#   3. scale the worker deployments to 0
#
# Reverse with ctl_api_unpause_worker_hpas, which re-applies the HPAs from the
# backup configmap.

set -e
set -o pipefail
set -u

cm="${BACKUP_CM:-ctl-api-worker-hpa-backup}"

# 1. back up current HPAs (only if no backup exists yet)
if kubectl -n ctl-api get configmap "$cm" >/dev/null 2>&1; then
  echo >&2 "backup configmap ${cm} already exists, keeping existing backup"
else
  hpas_json="[]"
  for ns in $WORKER_NAMESPACES; do
    hpa="ctl-api-worker-${ns}"
    obj=$(kubectl -n ctl-api get hpa "$hpa" -o json 2>/dev/null) || {
      echo >&2 "  hpa ${hpa} not found, skipping backup"
      continue
    }
    # strip server-managed fields so the manifest re-applies cleanly later
    clean=$(echo "$obj" | jq '
      del(.status, .metadata.resourceVersion, .metadata.uid,
          .metadata.creationTimestamp, .metadata.generation,
          .metadata.managedFields, .metadata.selfLink)
      | .metadata.annotations |= ((. // {})
          | with_entries(select(.key | startswith("kubectl.kubernetes.io") | not)))')
    hpas_json=$(jq -n --argjson a "$hpas_json" --argjson o "$clean" '$a + [$o]')
    echo >&2 "  backed up ${hpa}"
  done

  count=$(echo "$hpas_json" | jq 'length')
  if [ "$count" -eq 0 ]; then
    echo >&2 "no worker HPAs found to back up"
  fi
  echo "$hpas_json" | kubectl -n ctl-api create configmap "$cm" --from-file=hpas.json=/dev/stdin
  echo >&2 "saved ${count} HPA(s) to configmap ${cm}"
fi

# 2 + 3. delete HPAs and scale deployments to 0
for ns in $WORKER_NAMESPACES; do
  hpa="ctl-api-worker-${ns}"
  deploy="ctl-api-worker-${ns}"
  echo >&2 "deleting hpa ${hpa} and scaling deployment ${deploy} to 0"
  kubectl -n ctl-api delete hpa "$hpa" --ignore-not-found
  kubectl -n ctl-api scale deployment "$deploy" --replicas=0 || echo >&2 "warning: failed to scale ${deploy}"
done

echo ""
echo "current worker deployment state:"
kubectl -n ctl-api get deployments -l app.kubernetes.io/component=worker -o wide
