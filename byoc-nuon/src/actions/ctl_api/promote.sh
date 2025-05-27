#!/usr/bin/env bash

set -e
set -o pipefail
set -u

admin_api_addr="$ADMIN_API_URL"

echo "[ctl_api promote] executing ctl-api promote callback"

curl -X 'POST' \
  "$admin_api_addr/v1/general/promotion" \
  --data '{"tag":"byoc"}'
