#!/usr/bin/env bash

set -e
set -o pipefail
set -u

db_identifier="$DB_IDENTIFIER"

echo "getting disk metrics for $db_identifier"

now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
one_hour_ago=$(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)

free_storage_bytes=$(aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name FreeStorageSpace \
  --dimensions Name=DBInstanceIdentifier,Value="$db_identifier" \
  --start-time "$one_hour_ago" \
  --end-time "$now" \
  --period 300 \
  --statistics Average \
  --output json | jq -r '.Datapoints | sort_by(.Timestamp) | last | .Average // empty')

allocated_gb=$(aws rds describe-db-instances \
  --db-instance-identifier "$db_identifier" \
  --query 'DBInstances[0].AllocatedStorage' \
  --output text)

if [ -z "$free_storage_bytes" ]; then
  echo "no recent FreeStorageSpace datapoints found"
  results=$(jq -nc --arg alloc "$allocated_gb" '{
    allocated_storage_gb: ($alloc | tonumber),
    free_storage_gb: "unknown",
    used_storage_gb: "unknown",
    used_pct: "unknown",
    free_pct: "unknown"
  }')
else
  results=$(jq -nc \
    --arg free_bytes "$free_storage_bytes" \
    --arg alloc "$allocated_gb" '{
      allocated_storage_gb: ($alloc | tonumber),
      free_storage_gb: (($free_bytes | tonumber) / 1073741824 * 100 | round / 100),
      used_storage_gb: (($alloc | tonumber) - (($free_bytes | tonumber) / 1073741824 * 100 | round / 100)),
      used_pct: ((($alloc | tonumber) - (($free_bytes | tonumber) / 1073741824 * 100 | round / 100)) / ($alloc | tonumber) * 100 * 10 | round / 10),
      free_pct: ((($free_bytes | tonumber) / 1073741824 * 100 | round / 100) / ($alloc | tonumber) * 100 * 10 | round / 10)
    }')
fi

echo "$results"
echo "$results" >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
