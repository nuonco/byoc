#!/usr/bin/env bash

set -e
set -o pipefail
set -u

# Verifies ClickHouse persistent storage:
#   1. lists PVCs and flags any that are not Bound
#   2. confirms the data dir is backed by a real disk (not an ephemeral overlay)
#   3. (optional, disruptive) writes a row, restarts the StatefulSet, and confirms the
#      row survived — the durability proof. Gated behind RUN_RESTART_TEST=true.
#
# Optional env:
#   RUN_RESTART_TEST  "true" to run the disruptive write/restart/read test (default "false")
#
# Emits (to $NUON_ACTIONS_OUTPUT_FILEPATH): indicator, pvcs_bound, pvcs_total,
#   unbound_pvcs, data_mount, restart_test, updated_at

NS=clickhouse

echo "### PVCs (expect one per server replica, Bound, 20Gi, storageclass ssd)"
kubectl -n "$NS" get pvc

pvcs_total=$(kubectl -n "$NS" get pvc -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -c . || true)
pvcs_bound=$(kubectl -n "$NS" get pvc -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' | grep -c '^Bound$' || true)
unbound=$(kubectl -n "$NS" get pvc \
  -o jsonpath='{range .items[*]}{.metadata.name}={.status.phase}{"\n"}{end}' \
  | grep -v '=Bound' || true)
if [ -n "$unbound" ]; then
  echo "WARNING: unbound PVCs:"
  echo "$unbound"
fi

echo
echo "### Data dir mount (should be a real PV device, not overlay/tmpfs)"
pod=$(kubectl -n "$NS" get pods -l clickhouse.altinity.com/chi=clickhouse-installation \
  -o jsonpath='{.items[0].metadata.name}')
echo "using pod: $pod"
kubectl -n "$NS" exec "$pod" -- df -h /var/lib/clickhouse
data_mount=$(kubectl -n "$NS" exec "$pod" -- df -P /var/lib/clickhouse | tail -1 | awk '{print $1}')

restart_test="skipped"
if [ "${RUN_RESTART_TEST:-false}" = "true" ]; then
  echo
  echo "### Durability test (write -> rollout restart StatefulSet -> read back)"
  sts="chi-clickhouse-installation-simple-0-0"
  testpod="chi-clickhouse-installation-simple-0-0-0"
  kubectl -n "$NS" exec "$testpod" -- clickhouse client -q \
    "CREATE TABLE IF NOT EXISTS default.persist_check (id UInt32) ENGINE=MergeTree ORDER BY id"
  kubectl -n "$NS" exec "$testpod" -- clickhouse client -q \
    "INSERT INTO default.persist_check VALUES (42)"
  kubectl -n "$NS" rollout restart statefulset "$sts"
  kubectl -n "$NS" rollout status statefulset "$sts" --timeout=180s
  count=$(kubectl -n "$NS" exec "$testpod" -- clickhouse client -q \
    "SELECT count() FROM default.persist_check")
  kubectl -n "$NS" exec "$testpod" -- clickhouse client -q \
    "DROP TABLE default.persist_check"
  if [ "$count" = "1" ]; then
    restart_test="passed"
  else
    restart_test="failed (count=$count)"
  fi
  echo "durability restart test: $restart_test"
fi

# 🟢 when every PVC is Bound and the restart test (if run) passed; 🔴 otherwise
indicator="🟢"
if [ -n "$unbound" ]; then indicator="🔴"; fi
case "$restart_test" in failed*) indicator="🔴" ;; esac

jq -n -c \
  --arg ind "$indicator" \
  --arg pb "$pvcs_bound" \
  --arg pt "$pvcs_total" \
  --arg dm "$data_mount" \
  --arg rt "$restart_test" \
  --arg ub "$unbound" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{indicator: $ind, pvcs_bound: ($pb|tonumber), pvcs_total: ($pt|tonumber), data_mount: $dm, restart_test: $rt, unbound_pvcs: ($ub | split("\n") | map(select(length > 0))), updated_at: $ts}' \
  >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
