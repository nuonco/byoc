#!/usr/bin/env bash

set -e
set -o pipefail
set -u

# Snapshot of CPU / memory / disk for the ClickHouse replica pods, sourced
# entirely from the kubelet Summary API — no ClickHouse query and no exec, so it
# survives the DB query lockdown. One row per pod.
#
# Needs RBAC for nodes/proxy (the stats/summary subresource) and nodes (get).
#
# Env:
#   NAMESPACE   clickhouse namespace (default: clickhouse)
#   CH_SELECTOR label selector for the CH pods

ns="${NAMESPACE:-clickhouse}"
selector="${CH_SELECTOR:-clickhouse.altinity.com/chi=clickhouse-installation}"

echo "=== ClickHouse health (snapshot) — $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
echo

FMT='%-36s %-7s %-11s %-16s %-11s %-16s\n'
printf "$FMT" POD CPU% MEM_USED% MEM_Gi DISK_USED% DISK_Gi

# k8s resource quantity (e.g. "4", "3920m", "16093888Ki", "20Gi") -> number
# (cores for cpu, bytes for memory) — shared jq prelude.
JQ_QTY='
  def qty:
    if . == null then null
    elif type == "number" then .
    else . as $s
      | if   ($s|test("Ki$")) then (($s|rtrimstr("Ki")|tonumber) * 1024)
        elif ($s|test("Mi$")) then (($s|rtrimstr("Mi")|tonumber) * 1048576)
        elif ($s|test("Gi$")) then (($s|rtrimstr("Gi")|tonumber) * 1073741824)
        elif ($s|test("Ti$")) then (($s|rtrimstr("Ti")|tonumber) * 1099511627776)
        elif ($s|test("m$"))  then (($s|rtrimstr("m")|tonumber) / 1000)
        else ($s|tonumber) end
    end;
  def gib($b): if $b == null then null else ($b / 1073741824 * 10 | round) / 10 end;
  def r1($n): if $n == null then null else ($n * 10 | round) / 10 end;
'

fmt_num() { if [ "$1" = "null" ] || [ -z "$1" ]; then echo "n/a"; else echo "${1}${2:-}"; fi; }
fmt_pair() {
  if [ "$1" = "null" ] || [ "$2" = "null" ]; then echo "n/a"; else echo "${1}/${2}Gi"; fi
}

# pod -> node mapping
pods=$(kubectl get pods -n "$ns" -l "$selector" \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.nodeName}{"\n"}{end}')

while IFS=$'\t' read -r pod node; do
  [ -z "$pod" ] && continue

  summary=$(kubectl get --raw "/api/v1/nodes/${node}/proxy/stats/summary")
  node_json=$(kubectl get node "$node" -o json)

  row=$(jq -nc \
    --argjson s "$summary" \
    --argjson n "$node_json" \
    --arg ns "$ns" \
    --arg pod "$pod" \
    "$JQ_QTY"'
    ($n.status.allocatable.cpu | qty)    as $node_cpu
    | ($n.status.allocatable.memory | qty) as $node_mem
    | ($s.pods[] | select(.podRef.namespace == $ns and .podRef.name == $pod)) as $p
    | ($p.cpu.usageNanoCores // null)       as $cpu_nanos
    | (if $cpu_nanos == null then null else $cpu_nanos / 1000000000 end) as $cpu_cores
    | ($p.memory.workingSetBytes // null)   as $mem_used
    | (($p.memory.availableBytes // null)) as $mem_avail
    | (if $mem_used != null and $mem_avail != null then ($mem_used + $mem_avail)
       else $node_mem end)                  as $mem_total
    # the PVC-backed data volume (skip configmap/secret mounts)
    | ([$p.volume[]? | select(.pvcRef != null)]
        | (map(select(.name | test("data"))) + .) | first)  as $vol
    | ($vol.usedBytes // null)              as $disk_used
    | ($vol.capacityBytes // null)          as $disk_total
    | {
        label:          $pod,
        cpu_pct:        (if $cpu_cores != null and $node_cpu and $node_cpu > 0
                          then (($cpu_cores / $node_cpu) * 100 * 10 | round) / 10 else null end),
        mem_used_pct:   (if $mem_used != null and $mem_total and $mem_total > 0
                          then (($mem_used / $mem_total) * 100 * 10 | round) / 10 else null end),
        mem_used_gib:   gib($mem_used),
        mem_total_gib:  gib($mem_total),
        disk_used_pct:  (if $disk_used != null and $disk_total and $disk_total > 0
                          then (($disk_used / $disk_total) * 100 * 10 | round) / 10 else null end),
        disk_used_gib:  gib($disk_used),
        disk_total_gib: gib($disk_total)
      }
    | with_entries(select(.value != null))')

  read -r cpu mem_pct mem_used mem_total disk_pct disk_used disk_total < <(
    echo "$row" | jq -r '[
      .cpu_pct, .mem_used_pct, .mem_used_gib, .mem_total_gib,
      .disk_used_pct, .disk_used_gib, .disk_total_gib
    ] | map(if . == null then "null" else tostring end) | @tsv')

  printf "$FMT" \
    "$pod" \
    "$(fmt_num "$cpu" %)" \
    "$(fmt_num "$mem_pct" %)" \
    "$(fmt_pair "$mem_used" "$mem_total")" \
    "$(fmt_num "$disk_pct" %)" \
    "$(fmt_pair "$disk_used" "$disk_total")"

  echo "$row" | jq -c '{(.label): .}' >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
done <<< "$pods"
