#!/usr/bin/env bash
#
# Unpause ctl-api worker autoscaling: re-applies the worker HPAs saved by
# ctl_api_pause_worker_hpas from the backup configmap. Once the HPAs exist
# again they restore each deployment's minReplicas, so the workers scale back
# up automatically — no manual scale needed.

set -e
set -o pipefail
set -u

cm="${BACKUP_CM:-ctl-api-worker-hpa-backup}"

if ! kubectl -n ctl-api get configmap "$cm" >/dev/null 2>&1; then
  echo >&2 "backup configmap ${cm} not found — nothing to unpause"
  echo >&2 "(was ctl_api_pause_worker_hpas run? did a previous unpause already delete the backup?)"
  exit 1
fi

hpas_json=$(kubectl -n ctl-api get configmap "$cm" -o jsonpath='{.data.hpas\.json}')
count=$(echo "$hpas_json" | jq 'length')
echo >&2 "re-applying ${count} worker HPA(s) from configmap ${cm}"

# wrap the saved HPAs in a List and apply
echo "$hpas_json" | jq '{apiVersion: "v1", kind: "List", items: .}' | kubectl apply -f -

# native HPA won't scale a deployment up from 0, so seed each to its minReplicas
echo "$hpas_json" | jq -r '.[] | "\(.spec.scaleTargetRef.name) \(.spec.minReplicas // 1)"' \
| while read -r deploy min; do
  echo >&2 "scaling deployment ${deploy} to ${min} replicas"
  kubectl -n ctl-api scale deployment "$deploy" --replicas="$min" || echo >&2 "warning: failed to scale ${deploy}"
done

# backup is consumed — remove it so a later pause takes a fresh snapshot
kubectl -n ctl-api delete configmap "$cm"
echo >&2 "deleted backup configmap ${cm}"

echo ""
echo "current worker HPA state:"
kubectl -n ctl-api get hpa -l app.kubernetes.io/component=worker -o wide
