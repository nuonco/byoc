#!/usr/bin/env bash

set -e
set -o pipefail
set -u

admin_api_addr="$ADMIN_API_URL"

# prepare outputs
OUTPUTS='{}'

# get org runners
org_runners=$(curl --max-time 5 -q -s \
  "$admin_api_addr/v1/runners?type=org" \
  -H 'accept: application/json' \
  -H 'X-Nuon-Admin-Email: jon@nuon.co')

# get install runners
install_runners=$(curl --max-time 5 -q -s \
  "$admin_api_addr/v1/runners?type=install" \
  -H 'accept: application/json' \
  -H 'X-Nuon-Admin-Email: jon@nuon.co')

# merge into single list
runners=$(echo "$org_runners" "$install_runners" | jq -s 'add')

for runner_id in $(echo "$runners" | jq -r '.[].id'); do
  org_id=$(echo "$runners" | jq -r --arg id "$runner_id" '.[] | select(.id == $id) | .org_id')
  settings=$(curl --max-time 5 -q -s \
    "$admin_api_addr/v1/runners/$runner_id/settings" \
    -H 'accept: application/json' \
    -H 'X-Nuon-Admin-Email: jon@nuon.co')

  OUTPUTS=$(echo "$OUTPUTS" | jq -c --arg id "$runner_id" --arg org "$org_id" --argjson settings "$settings" \
    '. + {($id): {org_id: $org, type: ($settings.metadata["runner.type"] // "unknown"), settings: $settings}}')
done

echo "$OUTPUTS" >> $NUON_ACTIONS_OUTPUT_FILEPATH
