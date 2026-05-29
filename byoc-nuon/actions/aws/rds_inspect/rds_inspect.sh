#!/usr/bin/env bash

set -e
set -o pipefail
set -u

# Inspects a single RDS instance and prints, in table format:
#   1. a one-line summary (instance id, class, time window)
#   2. the instance configuration (class, engine, storage, IOPS, AZ, ...)
#   3. OS-level metrics from Performance Insights for the last hour (CPU, memory, IOPS)
#
# Required env:
#   DB_RESOURCE_ID  the stable DbiResourceId of the instance (rds_cluster_*.outputs.db_instance_resource_id)
# Optional env:
#   DB_LABEL        human-friendly label used in the header (defaults to "database")

db_resource_id="$DB_RESOURCE_ID"
db_label="${DB_LABEL:-database}"

echo "==================================================================="
echo " RDS inspection: ${db_label}  (resource id: ${db_resource_id})"
echo "==================================================================="

# resolve the human instance identifier from the stable resource id, so this
# keeps working across instance renames / replacements
db_instance_id=$(aws rds describe-db-instances \
  --query "DBInstances[?DbiResourceId=='${db_resource_id}'].DBInstanceIdentifier" \
  --output text)

if [ -z "$db_instance_id" ]; then
  echo >&2 "error: no RDS instance found for resource id ${db_resource_id}"
  exit 1
fi

now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
one_hour_ago=$(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
            || date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)

class=$(aws rds describe-db-instances \
  --db-instance-identifier "$db_instance_id" \
  --query 'DBInstances[0].DBInstanceClass' --output text)

echo "instance=${db_instance_id}  class=${class}  window=${one_hour_ago} -> ${now}"
echo

echo "### Instance configuration"
aws rds describe-db-instances \
  --db-instance-identifier "$db_instance_id" \
  --query 'DBInstances[0].{
    Class:DBInstanceClass,
    Engine:Engine,
    EngineVersion:EngineVersion,
    Status:DBInstanceStatus,
    StorageType:StorageType,
    AllocatedGB:AllocatedStorage,
    MaxAllocatedGB:MaxAllocatedStorage,
    ProvisionedIOPS:Iops,
    StorageThroughputMBps:StorageThroughput,
    MultiAZ:MultiAZ,
    AZ:AvailabilityZone,
    PerfInsights:PerformanceInsightsEnabled,
    ParameterGroup:DBParameterGroups[0].DBParameterGroupName
  }' --output table

echo
echo "### Storage utilization"
allocated_gb=$(aws rds describe-db-instances \
  --db-instance-identifier "$db_instance_id" \
  --query 'DBInstances[0].AllocatedStorage' --output text)

# FreeStorageSpace is only in CloudWatch; take the most recent datapoint in the window
free_storage_bytes=$(aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name FreeStorageSpace \
  --dimensions Name=DBInstanceIdentifier,Value="$db_instance_id" \
  --start-time "$one_hour_ago" \
  --end-time "$now" \
  --period 300 \
  --statistics Average \
  --output json | jq -r '.Datapoints | sort_by(.Timestamp) | last | .Average // empty')

SFMT='%-14s %-14s %-12s %-12s %-10s\n'
printf "$SFMT" METRIC ALLOCATED_GB FREE_GB USED_GB USED%
if [ -z "$free_storage_bytes" ]; then
  printf "$SFMT" storage "${allocated_gb}GB" unknown unknown unknown
else
  read -r free_gb used_gb used_pct < <(jq -nr \
    --arg free_bytes "$free_storage_bytes" \
    --arg alloc "$allocated_gb" '
      ($free_bytes | tonumber / 1073741824 * 100 | round / 100) as $free
      | ($alloc | tonumber) as $a
      | ($a - $free)                          as $used
      | (($used / $a) * 100 * 10 | round / 10) as $pct
      | "\($free) \($used * 100 | round / 100) \($pct)"')
  printf "$SFMT" storage "${allocated_gb}GB" "${free_gb}GB" "${used_gb}GB" "${used_pct}%"
fi

# Performance Insights is required for the OS metric time-series below. Skip
# gracefully (rather than hard-failing under `set -e`) if it is not enabled.
pi_enabled=$(aws rds describe-db-instances \
  --db-instance-identifier "$db_instance_id" \
  --query 'DBInstances[0].PerformanceInsightsEnabled' --output text)

if [ "$pi_enabled" != "True" ]; then
  echo
  echo "### OS metrics (Performance Insights)"
  echo "Performance Insights is not enabled on ${db_instance_id}; skipping OS metric table."
  exit 0
fi

echo
echo "### OS metrics (Performance Insights, last hour @ 60s)"

FMT='%-26s %-5s %-6s %-7s %-7s %-7s %-7s %-9s %-9s %-12s %-10s %-11s %-11s %-9s %-10s %-10s %-10s\n'
printf "$FMT" TIMESTAMP CPU% AAS TOTAL CACHE USED AVAIL MEM_USED% STORAGE% SWAPOUT_KBs READ_IOPS WRITE_IOPS TOTAL_IOPS READ_KBs WRITE_KBs NET_RX_MBs NET_TX_MBs

aws pi get-resource-metrics \
  --service-type RDS --identifier "$db_resource_id" \
  --metric-queries '[
    {"Metric":"db.load.avg"},
    {"Metric":"os.fileSys.usedPercent.avg"},
    {"Metric":"os.cpuUtilization.total.avg"},
    {"Metric":"os.memory.total.avg"},
    {"Metric":"os.memory.free.avg"},
    {"Metric":"os.memory.cached.avg"},
    {"Metric":"os.memory.buffers.avg"},
    {"Metric":"os.swap.out.avg"},
    {"Metric":"os.diskIO.readIOsPS.avg"},
    {"Metric":"os.diskIO.writeIOsPS.avg"},
    {"Metric":"os.diskIO.readKbPS.avg"},
    {"Metric":"os.diskIO.writeKbPS.avg"},
    {"Metric":"os.network.rx.avg"},
    {"Metric":"os.network.tx.avg"}
  ]' \
  --start-time "$one_hour_ago" --end-time "$now" \
  --period-in-seconds 60 \
| jq -r '
    (.MetricList | map({key: .Key.Metric, value: .DataPoints}) | from_entries) as $m
    | $m["db.load.avg"]                 as $aas
    | $m["os.fileSys.usedPercent.avg"]  as $stor
    | $m["os.cpuUtilization.total.avg"] as $cpu
    | $m["os.memory.total.avg"]         as $tot
    | $m["os.memory.free.avg"]          as $fre
    | $m["os.memory.cached.avg"]        as $cac
    | $m["os.memory.buffers.avg"]       as $buf
    | $m["os.swap.out.avg"]             as $sw
    | $m["os.diskIO.readIOsPS.avg"]     as $rdiops
    | $m["os.diskIO.writeIOsPS.avg"]    as $wriops
    | $m["os.diskIO.readKbPS.avg"]      as $rdkb
    | $m["os.diskIO.writeKbPS.avg"]     as $wrkb
    | $m["os.network.rx.avg"]           as $netrx
    | $m["os.network.tx.avg"]           as $nettx
    | range(0; $cpu|length) as $i
    | (($tot[$i].Value // 0) / 1048576)                  as $total_gb
    | (($fre[$i].Value // 0) / 1048576)                  as $free_gb
    | (($cac[$i].Value // 0) / 1048576)                  as $cache_gb
    | (($buf[$i].Value // 0) / 1048576)                  as $buf_gb
    | ($total_gb - $free_gb - $cache_gb - $buf_gb)       as $used_gb
    | ($free_gb + $cache_gb + $buf_gb)                   as $avail_gb
    | ($cpu[$i].Timestamp) as $ts
    # AWS CLI may emit timestamps as ISO strings or epoch numbers depending on
    # cli_timestamp_format; normalize to ISO 8601 either way
    | [ (if ($ts | type) == "number" then ($ts | floor | todate) else $ts end),
        (($cpu[$i].Value // 0)|floor),
        ((($aas[$i].Value // 0) * 100 | round) / 100),
        ($total_gb|floor),
        ($cache_gb|floor),
        ($used_gb|floor),
        ($avail_gb|floor),
        ((($used_gb / $total_gb) * 100)|floor),
        ((($stor[$i].Value // 0) * 10 | round) / 10),
        (($sw[$i].Value // 0)|floor),
        ((($rdiops[$i].Value // 0) * 10 | round) / 10),
        ((($wriops[$i].Value // 0) * 10 | round) / 10),
        (((($rdiops[$i].Value // 0) + ($wriops[$i].Value // 0)) * 10 | round) / 10),
        ((($rdkb[$i].Value // 0) * 10 | round) / 10),
        ((($wrkb[$i].Value // 0) * 10 | round) / 10),
        ((($netrx[$i].Value // 0) / 1048576) * 10 | round / 10),
        ((($nettx[$i].Value // 0) / 1048576) * 10 | round / 10)
      ]
    | @tsv
  ' \
| while IFS=$'\t' read -r ts cpu aas total cache used avail usedpct storpct swap rd wr tot rdkb wrkb netrx nettx; do
    printf "$FMT" "$ts" "${cpu}%" "$aas" "${total}GB" "${cache}GB" "${used}GB" "${avail}GB" "${usedpct}%" "${storpct}%" "$swap" "$rd" "$wr" "$tot" "$rdkb" "$wrkb" "$netrx" "$nettx"
  done
