#!/usr/bin/env bash

set -e
set -o pipefail
set -u

db_addr="$DB_ADDR"
db_port="$DB_PORT"
db_name="$DB_NAME"

echo "getting db endpoint status for $db_name ($db_addr:$db_port)"

reachable="false"
if timeout 5 bash -c "</dev/tcp/$db_addr/$db_port" 2>/dev/null; then
  reachable="true"
fi

results=$(jq -nc --arg host "$db_addr" --arg port "$db_port" --arg db "$db_name" --arg reachable "$reachable" '{
  database: $db,
  host: $host,
  port: ($port | tonumber),
  status: (if ($reachable == "true") then "available" else "unreachable" end),
  engine: "postgresql-flexible-server"
}')

echo "$results"
echo "$results" >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
