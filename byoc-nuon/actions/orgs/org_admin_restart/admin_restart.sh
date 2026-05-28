#!/usr/bin/env bash

set -e
set -o pipefail
set -u

admin_api_addr="$ADMIN_API_URL"
org_id="$ORG_ID"

curl -X 'POST' -s -q \
  "$admin_api_addr/v1/orgs/$org_id/admin-restart" \
  -H 'accept: application/json' \
  -H 'X-Nuon-Admin-Email: jon@nuon.co' \
  -H 'Content-Type: application/json' \
  -d '{}'
