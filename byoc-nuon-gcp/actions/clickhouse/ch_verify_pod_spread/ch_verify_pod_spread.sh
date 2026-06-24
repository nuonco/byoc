#!/usr/bin/env bash

set -e
set -o pipefail
set -u

# Verifies the ClickHouse pod anti-affinity is in effect:
#   - the 2 server replicas must be on distinct nodes
#   - the 3 keeper replicas must be on distinct nodes (ideally distinct zones, to keep
#     raft quorum safe from a single zonal outage)
#
# Emits (to $NUON_ACTIONS_OUTPUT_FILEPATH): indicator, server_nodes, keeper_nodes,
#   keeper_distinct_zones, server_distinct_nodes_ok, keeper_distinct_nodes_ok, updated_at

NS=clickhouse
SERVER_SEL="clickhouse.altinity.com/chi=clickhouse-installation"
KEEPER_SEL="clickhouse-keeper.altinity.com/chk=clickhouse-keeper"

echo "### Server replicas"
kubectl -n "$NS" get pods -l "$SERVER_SEL" \
  -o custom-columns='POD:.metadata.name,NODE:.spec.nodeName,ZONE:.metadata.labels.topology\.kubernetes\.io/zone'

echo
echo "### Keeper replicas"
kubectl -n "$NS" get pods -l "$KEEPER_SEL" \
  -o custom-columns='POD:.metadata.name,NODE:.spec.nodeName,ZONE:.metadata.labels.topology\.kubernetes\.io/zone'

server_total=$(kubectl -n "$NS" get pods -l "$SERVER_SEL" -o jsonpath='{.items[*].spec.nodeName}' | tr ' ' '\n' | grep -c . || true)
server_distinct=$(kubectl -n "$NS" get pods -l "$SERVER_SEL" -o jsonpath='{.items[*].spec.nodeName}' | tr ' ' '\n' | sort -u | grep -c . || true)
keeper_total=$(kubectl -n "$NS" get pods -l "$KEEPER_SEL" -o jsonpath='{.items[*].spec.nodeName}' | tr ' ' '\n' | grep -c . || true)
keeper_distinct=$(kubectl -n "$NS" get pods -l "$KEEPER_SEL" -o jsonpath='{.items[*].spec.nodeName}' | tr ' ' '\n' | sort -u | grep -c . || true)
keeper_zones=$(kubectl -n "$NS" get pods -l "$KEEPER_SEL" -o jsonpath='{range .items[*]}{.metadata.labels.topology\.kubernetes\.io/zone}{"\n"}{end}' | sort -u | grep -c . || true)

server_ok=false
[ "$server_total" -gt 0 ] && [ "$server_total" = "$server_distinct" ] && server_ok=true
keeper_ok=false
[ "$keeper_total" -gt 0 ] && [ "$keeper_total" = "$keeper_distinct" ] && keeper_ok=true

indicator="🔴"
if [ "$server_ok" = "true" ] && [ "$keeper_ok" = "true" ]; then indicator="🟢"; fi

echo
echo "server: $server_distinct/$server_total distinct nodes (ok=$server_ok)"
echo "keeper: $keeper_distinct/$keeper_total distinct nodes, $keeper_zones distinct zones (ok=$keeper_ok)"

jq -n -c \
  --arg ind "$indicator" \
  --argjson so "$server_ok" \
  --argjson ko "$keeper_ok" \
  --arg sn "$server_distinct/$server_total" \
  --arg kn "$keeper_distinct/$keeper_total" \
  --argjson kz "$keeper_zones" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{indicator: $ind, server_distinct_nodes_ok: $so, keeper_distinct_nodes_ok: $ko, server_nodes: $sn, keeper_nodes: $kn, keeper_distinct_zones: $kz, updated_at: $ts}' \
  >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
