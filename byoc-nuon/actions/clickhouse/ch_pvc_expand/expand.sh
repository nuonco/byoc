#!/usr/bin/env bash
#
# Grow the ClickHouse data PVCs online. Self-contained: preflight -> enable SC
# expansion -> patch PVCs -> wait for resize -> verify. Additive only (never
# shrinks), and refuses to run if no CSI resizer is present (a resize without one
# hangs indefinitely). Online grow: no pod restart, no data rewrite.
#
# Env:
#   NAMESPACE        clickhouse namespace (default: clickhouse)
#   STORAGE_CLASS    StorageClass backing the data PVCs (default: ebi)
#   DATA_PVC_PREFIX  name prefix of the data PVCs (default: data-volume-template-)
#   TARGET_SIZE      target size, e.g. 100Gi (default: 100Gi)

set -uo pipefail

NS="${NAMESPACE:-clickhouse}"
SC="${STORAGE_CLASS:-ebi}"
PREFIX="${DATA_PVC_PREFIX:-data-volume-template-}"
TARGET="${TARGET_SIZE:-100Gi}"

# k8s quantity (e.g. 20Gi, 100Gi, 1Ti) -> bytes, for never-shrink comparison.
to_bytes() {
  awk -v s="$1" 'BEGIN {
    if (s ~ /Gi$/)      { sub(/Gi$/,"",s); print s*1073741824 }
    else if (s ~ /Mi$/) { sub(/Mi$/,"",s); print s*1048576 }
    else if (s ~ /Ti$/) { sub(/Ti$/,"",s); print s*1099511627776 }
    else                { print s+0 }
  }'
}
target_b=$(to_bytes "$TARGET")

##############################################################################
# 0. PREFLIGHT (read-only) — print state, gate on the CSI resizer.
##############################################################################
echo "=== ch_pvc_expand -> $TARGET  ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ==="
echo
echo "--- preflight: data PVCs ---"
kubectl get pvc -n "$NS" -o custom-columns=\
'NAME:.metadata.name,REQ:.spec.resources.requests.storage,CAP:.status.capacity.storage,SC:.spec.storageClassName,PHASE:.status.phase'

echo
echo "--- preflight: StorageClass '$SC' ---"
expand=$(kubectl get storageclass "$SC" -o jsonpath='{.allowVolumeExpansion}' 2>/dev/null)
echo "allowVolumeExpansion=${expand:-<unset>}"

echo
echo "--- preflight: CSI resizer (required; a resize without it hangs) ---"
resizer=$(kubectl get pods -A \
  -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.name}{"\n"}{end}{end}' 2>/dev/null \
  | grep -c 'csi-resizer')
echo "csi-resizer containers: ${resizer:-0}"
if [ "${resizer:-0}" -lt 1 ]; then
  echo "!! no csi-resizer present — refusing to patch (resize would hang). ABORT."
  exit 1
fi

echo
echo "--- preflight: PVC retention policy on StatefulSets (must not be Delete) ---"
# The clickhouse_cluster redeploy makes the operator recreate the STS to apply
# the new volumeClaimTemplates size. If a STS has whenDeleted=Delete, that
# recreation would DROP the data PVC. Unset defaults to Retain (safe); only an
# explicit Delete is dangerous. Abort if any CH StatefulSet is set to Delete.
retain_bad=0
stss=$(kubectl get sts -n "$NS" \
  -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.persistentVolumeClaimRetentionPolicy.whenDeleted}{"\n"}{end}' 2>/dev/null)
while IFS=' ' read -r name whenDeleted; do
  [ -z "$name" ] && continue
  echo "  ${name}: whenDeleted=${whenDeleted:-Retain (default)}"
  [ "$whenDeleted" = "Delete" ] && retain_bad=$((retain_bad + 1))
done <<EOF
$stss
EOF
if [ "$retain_bad" -gt 0 ]; then
  echo "  !! a StatefulSet has whenDeleted=Delete — the clickhouse_cluster redeploy"
  echo "     recreates the STS and would DROP the data PVC. Refusing to proceed. ABORT."
  exit 1
fi

echo
echo "--- preflight OK ---"
echo

##############################################################################
# 1. Enable expansion on the StorageClass (mutable false->true, non-destructive).
##############################################################################
echo "--- 1. enable expansion on StorageClass '$SC' ---"
if [ "$expand" != "true" ]; then
  kubectl patch storageclass "$SC" --type merge -p '{"allowVolumeExpansion":true}' \
    || { echo "!! failed to patch StorageClass"; exit 1; }
fi
kubectl get storageclass "$SC" -o jsonpath='allowVolumeExpansion={.allowVolumeExpansion}{"\n"}'
echo

##############################################################################
# 2. Grow the data PVCs to TARGET (never shrink).
##############################################################################
echo "--- 2. grow data PVCs to $TARGET ---"
pvcs=$(kubectl get pvc -n "$NS" -o name 2>/dev/null | sed 's|persistentvolumeclaim/||' | grep "^${PREFIX}")
if [ -z "$pvcs" ]; then
  echo "!! no data PVCs matched prefix '$PREFIX' in namespace '$NS'"; exit 1
fi
for pvc in $pvcs; do
  cur=$(kubectl get pvc -n "$NS" "$pvc" -o jsonpath='{.spec.resources.requests.storage}')
  cur_b=$(to_bytes "$cur")
  if [ "$target_b" -le "$cur_b" ]; then
    echo "  ${pvc}: current ${cur} >= target ${TARGET} — skip (never shrink)"
    continue
  fi
  echo "  ${pvc}: ${cur} -> ${TARGET}"
  kubectl patch pvc -n "$NS" "$pvc" --type merge \
    -p "{\"spec\":{\"resources\":{\"requests\":{\"storage\":\"${TARGET}\"}}}}" \
    || { echo "  !! patch failed for ${pvc}"; exit 1; }
done
echo

##############################################################################
# 3. Wait for the resize to reach capacity (up to ~4m).
##############################################################################
echo "--- 3. waiting for resize to complete ---"
for i in $(seq 1 24); do
  pending=0
  for pvc in $pvcs; do
    cap=$(kubectl get pvc -n "$NS" "$pvc" -o jsonpath='{.status.capacity.storage}')
    [ "$(to_bytes "${cap:-0}")" -lt "$target_b" ] && pending=$((pending + 1))
  done
  [ "$pending" -eq 0 ] && { echo "  all PVCs at ${TARGET}"; break; }
  echo "  waiting... (${pending} pending) [${i}/24]"
  sleep 10
done
echo

##############################################################################
# 4. Final state.
##############################################################################
echo "--- 4. final state ---"
kubectl get pvc -n "$NS" -o custom-columns=\
'NAME:.metadata.name,REQ:.spec.resources.requests.storage,CAP:.status.capacity.storage,PHASE:.status.phase'
echo "=== done ==="
