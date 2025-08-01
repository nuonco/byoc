#!/usr/bin/env bash

set -e
set -o pipefail
set -u

admin_api_addr="$ADMIN_API_URL"

# one time
curl -X 'POST' \
  "$admin_api_addr/v1/general/terminate-event-loops" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{}'

echo "[ctl_api promote] executing ctl-api promote callback"
curl -s --max-time 5 -q -X 'POST' \
  "$admin_api_addr/v1/general/promotion" \
  --data '{"tag":"byoc"}'
