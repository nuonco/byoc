#!/usr/bin/env sh

set -e
set -o pipefail
set -u

admin_api_addr="$ADMIN_API_URL"

curl --max-time 5 -q \
  "$admin_api_addr/v1/orgs/$org_id/forget" \
  | jq .
