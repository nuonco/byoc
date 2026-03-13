#!/usr/bin/env bash

set -e
set -o pipefail
set -u

admin_api_addr="$ADMIN_API_URL"
operation="$OPERATION"
org_id="$ORG_ID"

if [[ "$operation" == "add" ]]; then
  echo "[support users] add support users"
  curl -s -X 'POST' "$admin_api_addr/v1/orgs/$org_id/admin-support-users"
elif [[ "$operation" == "remove" ]]; then
  echo " > warn: pending implemenetion: $action"
else
  echo " > error: unsupported action: $action"
fi
