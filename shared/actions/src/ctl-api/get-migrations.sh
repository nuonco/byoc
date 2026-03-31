#!/usr/bin/env bash

set -e
set -o pipefail
set -u

admin_api_addr="$ADMIN_API_URL"

echo "get ctl-api migrations data"
migrations=`curl -s  "$admin_api_addr/v1/general/migrations" | jq -c`

echo "format migrations data"
echo $migrations | jq -r '.[] | "\(.created_at) \(.status) \(.name)"'
outputs=`jq --null-input --argjson migrationsVar "$migrations" '{"migrations": $migrationsVar}'`

echo "save migrations data to outputs"
echo $outputs >> $NUON_ACTIONS_OUTPUT_FILEPATH
