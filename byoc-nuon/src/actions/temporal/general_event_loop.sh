#!/usr/bin/env bash

set -e
set -o pipefail
set -u

admin_api_addr="$ADMIN_API_URL"

echo "[ctl_api promote] restarting general event loop"
curl -s --max-time 5 -q -X 'POST' \
  "$admin_api_addr/v1/general/restart-event-loop" \
  --data '{}'
