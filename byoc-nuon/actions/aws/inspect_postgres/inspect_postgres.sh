#!/usr/bin/env bash

set -e
set -o pipefail
set -u

# Prints 1-hour average health metrics for the Postgres RDS instances, one row
# each, sourced entirely from Performance Insights:
#   CPU%, memory used% (+ used/total Gi), disk used% (+ used/total Gi),
#   read/write/total IOPS, and DB load (average active sessions).
#
# Each DB is passed as a "<label>|<resource_id>" entry in DBS (newline-separated).
# resource_id is the stable DbiResourceId (rds_cluster_*.outputs.db_instance_resource_id);
# PI is keyed by it, so no describe-db-instances lookup is needed.

now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
one_hour_ago=$(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
            || date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)

echo "=== Database health (1-hour average) — window ${one_hour_ago} -> ${now} ==="
echo

FMT='%-16s %-7s %-10s %-16s %-11s %-16s %-11s %-12s %-12s %-9s\n'
printf "$FMT" DATABASE CPU% MEM_USED% MEM_Gi DISK_USED% DISK_Gi READ_IOPS WRITE_IOPS TOTAL_IOPS DB_LOAD

# compute the per-DB metrics from a PI get-resource-metrics response. emits a
# compact JSON object with numeric fields (or null when a metric is missing).
compute_row() {
  local label="$1"
  jq -c --arg label "$label" '
    def avg($a): if ($a | length) > 0 then (($a | add) / ($a | length)) else null end;
    def r1($n): if $n == null then null else ($n * 10    | round) / 10    end;
    def r2($n): if $n == null then null else ($n * 100   | round) / 100   end;
    def gib($kb): if $kb == null then null else ($kb / 1048576 * 10 | round) / 10 end;

    (.MetricList
      | map({ key: .Key.Metric, value: avg([.DataPoints[].Value // empty]) })
      | from_entries) as $m

    | $m["os.memory.total.avg"]   as $mtot
    | $m["os.memory.free.avg"]    as $mfree
    | $m["os.memory.cached.avg"]  as $mcache
    | $m["os.memory.buffers.avg"] as $mbuf
    | (if ($mtot != null and $mfree != null and $mcache != null and $mbuf != null)
        then ($mtot - $mfree - $mcache - $mbuf) else null end) as $mused

    | $m["os.fileSys.used.avg"]  as $fsused
    | $m["os.fileSys.total.avg"] as $fstot

    | $m["os.diskIO.readIOsPS.avg"]  as $rd
    | $m["os.diskIO.writeIOsPS.avg"] as $wr

    | {
        label:          $label,
        cpu_pct:        r1($m["os.cpuUtilization.total.avg"]),
        mem_used_pct:   (if ($mused != null and $mtot != null and $mtot > 0)
                          then (($mused / $mtot) * 100 * 10 | round) / 10 else null end),
        mem_used_gib:   gib($mused),
        mem_total_gib:  gib($mtot),
        disk_used_pct:  r1($m["os.fileSys.usedPercent.avg"]),
        disk_used_gib:  gib($fsused),
        disk_total_gib: gib($fstot),
        read_iops:      r1($rd),
        write_iops:     r1($wr),
        total_iops:     (if ($rd != null and $wr != null) then (($rd + $wr) * 10 | round) / 10 else null end),
        db_load:        r2($m["db.load.avg"])
      }
    # drop null metrics so the readme can distinguish "missing" (key absent ->
    # renders —) from a real zero (key present, value 0)
    | with_entries(select(.value != null))'
}

# pretty-print a "used/total Gi" pair, or "n/a" if either side is missing
fmt_pair() {
  local used="$1" total="$2"
  if [ "$used" = "null" ] || [ "$total" = "null" ]; then
    echo "n/a"
  else
    echo "${used}/${total}Gi"
  fi
}

# null/empty -> n/a, optionally with a suffix (e.g. "%")
fmt_num() {
  local val="$1" suffix="${2:-}"
  if [ "$val" = "null" ] || [ -z "$val" ]; then echo "n/a"; else echo "${val}${suffix}"; fi
}

while IFS= read -r entry; do
  [ -z "$entry" ] && continue
  label="${entry%%|*}"
  resource_id="${entry#*|}"

  metrics=$(aws pi get-resource-metrics \
    --service-type RDS --identifier "$resource_id" \
    --metric-queries '[
      {"Metric":"db.load.avg"},
      {"Metric":"os.cpuUtilization.total.avg"},
      {"Metric":"os.memory.total.avg"},
      {"Metric":"os.memory.free.avg"},
      {"Metric":"os.memory.cached.avg"},
      {"Metric":"os.memory.buffers.avg"},
      {"Metric":"os.fileSys.used.avg"},
      {"Metric":"os.fileSys.total.avg"},
      {"Metric":"os.fileSys.usedPercent.avg"},
      {"Metric":"os.diskIO.readIOsPS.avg"},
      {"Metric":"os.diskIO.writeIOsPS.avg"}
    ]' \
    --start-time "$one_hour_ago" --end-time "$now" \
    --period-in-seconds 3600)

  row=$(echo "$metrics" | compute_row "$label")

  read -r cpu mem_pct mem_used mem_total disk_pct disk_used disk_total rd wr tot load < <(
    echo "$row" | jq -r '[
      .cpu_pct, .mem_used_pct, .mem_used_gib, .mem_total_gib,
      .disk_used_pct, .disk_used_gib, .disk_total_gib,
      .read_iops, .write_iops, .total_iops, .db_load
    ] | map(if . == null then "null" else tostring end) | @tsv')

  printf "$FMT" \
    "$label" \
    "$(fmt_num "$cpu" %)" \
    "$(fmt_num "$mem_pct" %)" \
    "$(fmt_pair "$mem_used" "$mem_total")" \
    "$(fmt_num "$disk_pct" %)" \
    "$(fmt_pair "$disk_used" "$disk_total")" \
    "$(fmt_num "$rd")" \
    "$(fmt_num "$wr")" \
    "$(fmt_num "$tot")" \
    "$(fmt_num "$load")"

  # structured output for the readme to render: key by label so the per-DB
  # objects merge into a map (outputs.steps.databases) rather than overwriting
  echo "$row" | jq -c '{(.label): .}' >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
done <<< "$DBS"
