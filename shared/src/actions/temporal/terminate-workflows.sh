#!/usr/bin/env bash

set -e
set -o pipefail
set -u

admin_api_addr="$ADMIN_API_URL"
admin_email='jon@nuon.co'

echo "[ctl_api promote] terminating event loop workflows"
curl -s --max-time 5 -q -X 'POST'                    \
  "$admin_api_addr/v1/general/terminate-event-loops" \
  -H "X-Nuon-Admin-Email: $admin_email"              \
  --data '{}'
