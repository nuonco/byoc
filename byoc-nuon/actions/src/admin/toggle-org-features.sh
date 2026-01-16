#!/bin/bash

set -e
set -o pipefail
set -u

admin_api_url="$ADMIN_API_URL" # from env vars
mode="$MODE" # enable or diable


ENABLE_PAYLOAD='{"features": {"stratus-layout": true, "stratus-workflow": true, "dashboard-sse": true}}'
DISABLE_PAYLOAD='{"features": {"stratus-layout": false, "stratus-workflow": false, "dashboard-sse": false}}'


if [[ "$mode" == "enable" ]]; then
  payload="$ENABLE_PAYLOAD"
else
  payload="$DISABLE_PAYLOAD"
fi

curl -s \
  --max-time 5 \
  -q \
  -X 'PATCH' \
  "$admin_api_url/v1/orgs/admin-features" \
  -H "Authorization:jatin@retool.com" \
  --data "$payload"

curl -s --max-time 5 -q -X 'GET' -H "Authorization:jatin@retool.com" "$admin_api_url/v1/orgs/admin-features"
