#!/usr/bin/env bash

set -e
set -o pipefail
set -u

# Inspects a single Cloud SQL instance and prints:
#   1. a one-line summary (instance name, tier, state)
#   2. the instance configuration (tier, engine, storage, AZ, ...)
#   3. the most recent operations against the instance
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
