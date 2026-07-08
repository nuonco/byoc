#!/usr/bin/env bash

set -e
set -o pipefail
set -u

# Inspects a single Cloud SQL instance and prints:
#   1. a one-line summary (instance name, tier, state)
#   2. the instance configuration (tier, engine, storage, AZ, ...)
#   3. the most recent operations against the instance
#   4. OS-level metrics from Cloud Monitoring for the last hour (CPU, memory,
#      disk, IOPS, network, connections)
#
# Required env:
#   DB_INSTANCE_NAME  the Cloud SQL instance name (cloudsql_*.outputs.db_instance_name)
#   PROJECT_ID        the GCP project id
# Optional env:
#   DB_LABEL          human-friendly label used in the header (defaults to "database")

db_instance_name="$DB_INSTANCE_NAME"
project_id="$PROJECT_ID"
db_label="${DB_LABEL:-database}"

echo "==================================================================="
echo " Cloud SQL inspection: ${db_label}  (instance: ${db_instance_name})"
echo "==================================================================="

instance_json=$(gcloud sql instances describe "$db_instance_name" \
  --project "$project_id" --format json)

tier=$(echo "$instance_json" | jq -r '.settings.tier // empty')
state=$(echo "$instance_json" | jq -r '.state // empty')

echo "instance=${db_instance_name}  tier=${tier}  state=${state}"
echo

echo "### Instance configuration"
echo "$instance_json" | jq '{
  Tier: .settings.tier,
  Edition: .settings.edition,
  Engine: .databaseVersion,
  MaintenanceVersion: .maintenanceVersion,
  State: .state,
  StorageType: .settings.dataDiskType,
  AllocatedGB: .settings.dataDiskSizeGb,
  StorageAutoResize: .settings.storageAutoResize,
  StorageAutoResizeLimitGB: .settings.storageAutoResizeLimit,
  AvailabilityType: .settings.availabilityType,
  Region: .region,
  Zone: .gceZone,
  PrivateIP: ([.ipAddresses[]? | select(.type == "PRIVATE") | .ipAddress] | first),
  BackupsEnabled: .settings.backupConfiguration.enabled,
  PITREnabled: .settings.backupConfiguration.pointInTimeRecoveryEnabled,
  InsightsEnabled: .settings.insightsConfig.queryInsightsEnabled,
  DatabaseFlags: (.settings.databaseFlags // [])
}'

echo
echo "### Recent operations (last 10)"
gcloud sql operations list \
  --instance "$db_instance_name" \
  --project "$project_id" \
  --limit 10

# OS metrics from Cloud Monitoring (needs roles/monitoring.viewer). Gauges use
# ALIGN_MEAN; DELTA counters (IOPS, network bytes) use ALIGN_RATE for per-second values.
echo
echo "### OS metrics (Cloud Monitoring, last hour @ 60s)"

now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
one_hour_ago=$(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
            || date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)

token=$(gcloud auth print-access-token 2>/dev/null || true)
if [ -z "$token" ]; then
  echo "could not obtain an access token; skipping OS metric table."
  exit 0
fi

database_id="${project_id}:${db_instance_name}"

# Fetch one metric's aligned time-series as a compact {endTime: value} map.
fetch_map() {
  local metric="$1" aligner="$2"
  curl -sG "https://monitoring.googleapis.com/v3/projects/${project_id}/timeSeries" \
    -H "Authorization: Bearer ${token}" \
    --data-urlencode "filter=metric.type=\"${metric}\" AND resource.labels.database_id=\"${database_id}\"" \
    --data-urlencode "interval.startTime=${one_hour_ago}" \
    --data-urlencode "interval.endTime=${now}" \
    --data-urlencode "aggregation.alignmentPeriod=60s" \
    --data-urlencode "aggregation.perSeriesAligner=${aligner}" \
    2>/dev/null \
  | jq -c '[.timeSeries[]?.points[]?
             | {key: .interval.endTime,
                value: (.value.doubleValue // .value.int64Value // 0)}]
           | from_entries' 2>/dev/null || echo '{}'
}

cpu=$(fetch_map   "cloudsql.googleapis.com/database/cpu/utilization"            ALIGN_MEAN)
mem=$(fetch_map   "cloudsql.googleapis.com/database/memory/utilization"         ALIGN_MEAN)
disk=$(fetch_map  "cloudsql.googleapis.com/database/disk/utilization"           ALIGN_MEAN)
conns=$(fetch_map "cloudsql.googleapis.com/database/postgresql/num_backends"    ALIGN_MEAN)
rdio=$(fetch_map  "cloudsql.googleapis.com/database/disk/read_ops_count"        ALIGN_RATE)
wrio=$(fetch_map  "cloudsql.googleapis.com/database/disk/write_ops_count"       ALIGN_RATE)
netrx=$(fetch_map "cloudsql.googleapis.com/database/network/received_bytes_count" ALIGN_RATE)
nettx=$(fetch_map "cloudsql.googleapis.com/database/network/sent_bytes_count"   ALIGN_RATE)

FMT='%-26s %-6s %-6s %-6s %-6s %-10s %-11s %-11s %-11s %-11s\n'
printf "$FMT" TIMESTAMP CPU% MEM% DISK% CONNS READ_IOPS WRITE_IOPS TOTAL_IOPS NET_RX_MBs NET_TX_MBs

rows=$(jq -nr \
  --argjson cpu "$cpu" --argjson mem "$mem" --argjson disk "$disk" \
  --argjson conns "$conns" --argjson rdio "$rdio" --argjson wrio "$wrio" \
  --argjson netrx "$netrx" --argjson nettx "$nettx" '
    # union of all sample timestamps across every metric
    (($cpu + $mem + $disk + $conns + $rdio + $wrio + $netrx + $nettx) | keys) as $ts
    | $ts[]
    | . as $t
    | ($rdio[$t] // 0)  as $rd
    | ($wrio[$t] // 0)  as $wr
    | [ $t,
        (($cpu[$t]   // 0) * 100 | floor),
        (($mem[$t]   // 0) * 100 | floor),
        (($disk[$t]  // 0) * 100 | floor),
        (($conns[$t] // 0) | floor),
        (($rd) * 10 | round / 10),
        (($wr) * 10 | round / 10),
        (($rd + $wr) * 10 | round / 10),
        ((($netrx[$t] // 0) / 1048576) * 10 | round / 10),
        ((($nettx[$t] // 0) / 1048576) * 10 | round / 10)
      ]
    | @tsv
  ' 2>/dev/null || true)

if [ -z "$rows" ]; then
  echo "(no Cloud Monitoring samples in the window; metrics may lag by a few minutes)"
  exit 0
fi

echo "$rows" | while IFS=$'\t' read -r ts cpu mem disk conns rd wr tot rx tx; do
  printf "$FMT" "$ts" "${cpu}%" "${mem}%" "${disk}%" "$conns" "$rd" "$wr" "$tot" "$rx" "$tx"
done
