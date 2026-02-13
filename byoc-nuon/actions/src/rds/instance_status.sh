#!/usr/bin/env bash

set -e
set -o pipefail
set -u

db_identifier="$DB_IDENTIFIER"

echo "getting rds instance status for $db_identifier"

results=$(aws rds describe-db-instances \
  --db-instance-identifier "$db_identifier" \
  --query 'DBInstances[0]' \
  --output json | jq -c '{
    status: .DBInstanceStatus,
    engine: .Engine,
    engine_version: .EngineVersion,
    instance_class: .DBInstanceClass,
    allocated_storage_gb: .AllocatedStorage,
    max_allocated_storage_gb: .MaxAllocatedStorage,
    storage_type: .StorageType,
    multi_az: .MultiAZ,
    availability_zone: .AvailabilityZone,
    storage_encrypted: .StorageEncrypted,
    performance_insights_enabled: .PerformanceInsightsEnabled,
    backup_retention_period: .BackupRetentionPeriod
  }')

echo "$results"
echo "$results" >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
