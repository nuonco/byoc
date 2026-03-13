#!/usr/bin/env bash

set -e
set -o pipefail
set -u

db_addr="$DB_ADDR"
db_port="$DB_PORT"
db_name="$DB_NAME"

echo "getting db network health for $db_name ($db_addr:$db_port)"

reachable="false"
if timeout 5 bash -c "</dev/tcp/$db_addr/$db_port" 2>/dev/null; then
  reachable="true"
fi

results=$(jq -nc --arg host "$db_addr" --arg port "$db_port" --arg db "$db_name" --arg reachable "$reachable" '{
  database: $db,
  host: $host,
  port: ($port | tonumber),
  reachable: ($reachable == "true"),
  note: "Azure migration: Cloudwatch/RDS disk metrics are unavailable in this action runtime"
}')

echo "$results"
echo "$results" >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
