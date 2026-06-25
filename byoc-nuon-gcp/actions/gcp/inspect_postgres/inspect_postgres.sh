#!/usr/bin/env bash

set -e
set -o pipefail
set -u

# Prints 1-hour average health metrics for the Cloud SQL (Postgres) instances,
# one row each, sourced from Cloud Monitoring:
#   CPU%, memory used% (+ used/total Gi), disk used% (+ used/total Gi),
#   read/write/total IOPS.
#
# Cloud SQL has no Performance-Insights "average active sessions" equivalent, so
# the DB load column is left empty (renders — in the readme).
#
# Each DB is passed as a "<label>|<instance_name>" entry in DBS (newline-separated).
# Cloud Monitoring keys Cloud SQL series by resource.labels.database_id =
# "<project>:<instance_name>".
#
# Env:
#   DBS         newline-separated "<label>|<instance_name>" entries
#   PROJECT_ID  the GCP project id

project="$PROJECT_ID"

end=$(date -u +%Y-%m-%dT%H:%M:%SZ)
start=$(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
     || date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)
token=$(gcloud auth print-access-token)

echo "=== Database health (1-hour average) — window ${start} -> ${end} ==="
echo

FMT='%-16s %-7s %-10s %-16s %-11s %-16s %-11s %-12s %-12s %-9s\n'
printf "$FMT" DATABASE CPU% MEM_USED% MEM_Gi DISK_USED% DISK_Gi READ_IOPS WRITE_IOPS TOTAL_IOPS DB_LOAD

# mean of a Cloud SQL metric over the window. $1 metric type, $2 aligner
# (ALIGN_MEAN for gauges, ALIGN_RATE for the DELTA op counters), $3 database_id.
# Returns the mean across aligned points, or empty if no data.
ts_mean() {
  curl -s -G "https://monitoring.googleapis.com/v3/projects/${project}/timeSeries" \
    -H "Authorization: Bearer ${token}" \
    --data-urlencode "filter=metric.type=\"$1\" AND resource.labels.database_id=\"$3\"" \
    --data-urlencode "interval.startTime=${start}" \
    --data-urlencode "interval.endTime=${end}" \
    --data-urlencode "aggregation.alignmentPeriod=3600s" \
    --data-urlencode "aggregation.perSeriesAligner=$2" \
  | jq -r '[.timeSeries[]?.points[]?.value | (.doubleValue // .int64Value // empty) | tonumber]
           | if length > 0 then (add / length) else "" end'
}

fmt_num() { if [ "$1" = "null" ] || [ -z "$1" ]; then echo "n/a"; else echo "${1}${2:-}"; fi; }
fmt_pair() {
  if [ "$1" = "null" ] || [ "$2" = "null" ]; then echo "n/a"; else echo "${1}/${2}Gi"; fi
}

# fetch static instance config from the Cloud SQL Admin API.
fetch_config() {
  local inst="$1"
  curl -s "https://sqladmin.googleapis.com/v1/projects/${project}/instances/${inst}" \
    -H "Authorization: Bearer ${token}" \
  | jq -c '{
      instance_id:  .name,
      class:        .settings.tier,
      status:       .state,
      storage_type: .settings.dataDiskType,
      allocated_gb: (.settings.dataDiskSizeGb | tonumber),
      multi_az:     (.settings.availabilityType == "REGIONAL"),
      az:           .gceZone
    } | with_entries(select(.value != null))'
}

M='cloudsql.googleapis.com/database'

while IFS= read -r entry; do
  [ -z "$entry" ] && continue
  label="${entry%%|*}"
  inst="${entry#*|}"
  dbid="${project}:${inst}"

  cpu=$(ts_mean       "$M/cpu/utilization"        ALIGN_MEAN "$dbid")
  mem_util=$(ts_mean  "$M/memory/utilization"     ALIGN_MEAN "$dbid")
  mem_usage=$(ts_mean "$M/memory/usage"           ALIGN_MEAN "$dbid")
  mem_total=$(ts_mean "$M/memory/total_usage"     ALIGN_MEAN "$dbid")
  disk_used=$(ts_mean "$M/disk/bytes_used"        ALIGN_MEAN "$dbid")
  disk_quota=$(ts_mean "$M/disk/quota"            ALIGN_MEAN "$dbid")
  rd=$(ts_mean        "$M/disk/read_ops_count"    ALIGN_RATE "$dbid")
  wr=$(ts_mean        "$M/disk/write_ops_count"   ALIGN_RATE "$dbid")

  row=$(jq -nc \
    --arg label "$label" \
    --arg cpu "$cpu" --arg mu "$mem_util" --arg musage "$mem_usage" --arg mtu "$mem_total" \
    --arg du "$disk_used" --arg dq "$disk_quota" --arg rd "$rd" --arg wr "$wr" '
    def num($s): if $s == "" then null else ($s | tonumber) end;
    def r1($n): if $n == null then null else ($n * 10 | round) / 10 end;
    def gib($b): if $b == null then null else ($b / 1073741824 * 10 | round) / 10 end;

    num($cpu) as $cpu | num($mu) as $mu | num($musage) as $mus | num($mtu) as $mtu
    | num($du) as $du | num($dq) as $dq | num($rd) as $rd | num($wr) as $wr
    # total RAM = total_usage / utilization (utilization is the fraction of total)
    | (if $mtu != null and $mu != null and $mu > 0 then ($mtu / $mu) else null end) as $mem_total
    | {
        label:          $label,
        cpu_pct:        (if $cpu != null then ($cpu * 100 * 10 | round) / 10 else null end),
        mem_used_pct:   (if $mus != null and $mem_total != null and $mem_total > 0
                          then ($mus / $mem_total * 100 * 10 | round) / 10
                          elif $mu != null then ($mu * 100 * 10 | round) / 10 else null end),
        mem_used_gib:   gib($mus),
        mem_total_gib:  gib($mem_total),
        disk_used_pct:  (if $du != null and $dq != null and $dq > 0
                          then ($du / $dq * 100 * 10 | round) / 10 else null end),
        disk_used_gib:  gib($du),
        disk_total_gib: gib($dq),
        read_iops:      r1($rd),
        write_iops:     r1($wr),
        total_iops:     (if $rd != null and $wr != null then (($rd + $wr) * 10 | round) / 10 else null end),
        db_load:        null
      }
    | with_entries(select(.value != null))')

  read -r cpu_d mem_pct mem_used mem_total_d disk_pct disk_used disk_total rd_d wr_d tot < <(
    echo "$row" | jq -r '[
      .cpu_pct, .mem_used_pct, .mem_used_gib, .mem_total_gib,
      .disk_used_pct, .disk_used_gib, .disk_total_gib,
      .read_iops, .write_iops, .total_iops
    ] | map(if . == null then "null" else tostring end) | @tsv')

  printf "$FMT" \
    "$label" \
    "$(fmt_num "$cpu_d" %)" \
    "$(fmt_num "$mem_pct" %)" \
    "$(fmt_pair "$mem_used" "$mem_total_d")" \
    "$(fmt_num "$disk_pct" %)" \
    "$(fmt_pair "$disk_used" "$disk_total")" \
    "$(fmt_num "$rd_d")" \
    "$(fmt_num "$wr_d")" \
    "$(fmt_num "$tot")" \
    "n/a"

  config=$(fetch_config "$inst")
  row=$(echo "$row" | jq -c --argjson cfg "$config" '. + {config: $cfg}')

  echo "$config" | jq -r '"  \(.instance_id // "n/a")  \(.class // "n/a")  \(.storage_type // "n/a") \(.allocated_gb // "?")GB  multi-az=\(if .multi_az then "yes" else "no" end)  az=\(.az // "n/a")"'
  echo

  echo "$row" | jq -c '{(.label): .}' >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
done <<< "$DBS"
