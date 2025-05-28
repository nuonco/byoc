#!/usr/bin/env bash

set -e
set -o pipefail
set -u

admin_api_addr="$ADMIN_API_URL"
admin_api_addr="admin.internal.byoc.retool.dev"

echo "[ctl_api promote] executing ctl-api promote callback"
curl --max-time 5 -q -X 'POST' \
  "$admin_api_addr:8082/v1/general/promotion" \
  --data '{"tag":"byoc"}'
