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

FMT='%-26s %-5s %-7s %-7s %-7s %-7s %-6s %-12s %-10s %-11s %-11s\n'
printf "$FMT" TIMESTAMP CPU% TOTAL CACHE USED AVAIL USED% SWAPOUT_KBs READ_IOPS WRITE_IOPS TOTAL_IOPS

aws pi get-resource-metrics \
  --service-type RDS --identifier "$db_resource_id" \
  --metric-queries '[
    {"Metric":"os.cpuUtilization.total.avg"},
    {"Metric":"os.memory.total.avg"},
    {"Metric":"os.memory.free.avg"},
    {"Metric":"os.memory.cached.avg"},
    {"Metric":"os.memory.buffers.avg"},
    {"Metric":"os.swap.out.avg"},
    {"Metric":"os.diskIO.readIOsPS.avg"},
    {"Metric":"os.diskIO.writeIOsPS.avg"}
  ]' \
  --start-time "$one_hour_ago" --end-time "$now" \
  --period-in-seconds 60 \
| jq -r '
    (.MetricList | map({key: .Key.Metric, value: .DataPoints}) | from_entries) as $m
    | $m["os.cpuUtilization.total.avg"] as $cpu
    | $m["os.memory.total.avg"]         as $tot
    | $m["os.memory.free.avg"]          as $fre
    | $m["os.memory.cached.avg"]        as $cac
    | $m["os.memory.buffers.avg"]       as $buf
    | $m["os.swap.out.avg"]             as $sw
    | $m["os.diskIO.readIOsPS.avg"]     as $rdiops
    | $m["os.diskIO.writeIOsPS.avg"]    as $wriops
    | range(0; $cpu|length) as $i
    | (($tot[$i].Value // 0) / 1048576)                  as $total_gb
    | (($fre[$i].Value // 0) / 1048576)                  as $free_gb
    | (($cac[$i].Value // 0) / 1048576)                  as $cache_gb
    | (($buf[$i].Value // 0) / 1048576)                  as $buf_gb
    | ($total_gb - $free_gb - $cache_gb - $buf_gb)       as $used_gb
    | ($free_gb + $cache_gb + $buf_gb)                   as $avail_gb
    | [ $cpu[$i].Timestamp,
        (($cpu[$i].Value // 0)|floor),
        ($total_gb|floor),
        ($cache_gb|floor),
        ($used_gb|floor),
        ($avail_gb|floor),
        ((($used_gb / $total_gb) * 100)|floor),
        (($sw[$i].Value // 0)|floor),
        (($rdiops[$i].Value // 0)|floor),
        (($wriops[$i].Value // 0)|floor),
        ((($rdiops[$i].Value // 0) + ($wriops[$i].Value // 0))|floor)
      ]
    | @tsv
  ' \
| while IFS=$'\t' read -r ts cpu total cache used avail usedpct swap rd wr tot; do
    printf "$FMT" "$ts" "${cpu}%" "${total}GB" "${cache}GB" "${used}GB" "${avail}GB" "${usedpct}%" "$swap" "$rd" "$wr" "$tot"
  done
