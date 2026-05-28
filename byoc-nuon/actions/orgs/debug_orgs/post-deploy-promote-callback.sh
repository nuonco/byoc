#!/usr/bin/env bash

set -e
set -o pipefail
set -u

admin_api_addr="$ADMIN_API_URL"

curl --max-time 5 -q -s \
  "$admin_api_addr/v1/orgs?type=real" \
  | jq
