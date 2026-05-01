#!/bin/bash

set -e
set -o pipefail
set -u

api_addr="https://api.nuon.co"
admin_api_addr='http://ctl.nuon.us-west-2.prod.internal.nuon.co'
admin_email='fred@nuon.co'

runner_ids=$(curl -s -X 'GET' \
  "$admin_api_addr/v1/runners?type=install&offset=0&limit=100&page=0" \
  -H 'accept: application/json' \
  -H "X-Nuon-Admin-Email: $admin_email" | jq -r '.[].id')

for runner_id in $runner_ids; do
  echo "Runner $runner_id"
  process_ids=$(curl -s -X 'GET' \
    "$admin_api_addr/v1/runners/$runner_id/processes" \
    -H 'accept: application/json' \
    -H "X-Nuon-Admin-Email: $admin_email" | jq -r '.[].id')

  for process_id in $process_ids; do
    echo "  Restarting process $process_id"
    curl -s -X 'POST' \
      "$admin_api_addr/v1/runners/$runner_id/processes/$process_id" \
      -H 'accept: application/json' \
      -H "X-Nuon-Admin-Email: $admin_email" \
      -H 'Content-Type: application/json' \
      -d '{}' > /dev/null
  done
done
