#!/usr/bin/env bash

set -e
set -o pipefail
set -u

admin_api_addr="$ADMIN_API_URL"

echo "[ctl_api migrations] executing ctl-api migrations callback"
migrations=`curl -s  "$admin_api_addr/v1/general/migrations" | jq -c`

# print in human legible format
echo $migrations | jq -r '.[] | "\(.created_at) \(.status) \(.name)"'

echo $migrations >> $NUON_ACTIONS_OUTPUT_FILEPATH
