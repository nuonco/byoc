#!/usr/bin/env bash

set -e
set -o pipefail
set -u

admin_api_addr="$ADMIN_API_URL"

echo "[ctl_api promote] fetching ctl-api admin api"
kubectl get services -n ctl-api -o yaml
nslookup admin.internal.byoc.retool.dev

curl -X 'POST' \
  "$admin_api_addr/v1/general/promotion" \
  --data '{"tag":"byoc"}'

echo "[ctl_api promote] executing ctl-api promote callback"

curl -X 'POST' \
  "$admin_api_addr/v1/general/promotion" \
  --data '{"tag":"byoc"}'
