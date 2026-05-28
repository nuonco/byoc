#!/usr/bin/env bash
#
# Extend the expiry of a runner's service account token via the ctl-api admin API.
#
# Required env vars:
#   RUNNER_ID      - ID of the runner whose SA token to extend
#   ADMIN_API_URL  - base URL of the ctl-api admin API
#
# Optional env vars:
#   DURATION       - token extension duration (default: 8760h / 1 year)

set -e
set -o pipefail
set -u

# user-configurable env vars that control options
runner_id="$RUNNER_ID"
duration="${DURATION:-8760h}"
admin_api_addr="$ADMIN_API_URL"

echo "preparing to extend service account token for runner:$runner_id (duration: $duration)"

result=`curl -X 'POST' -s -q --max-time 5 \
  "$admin_api_addr/v1/runners/$runner_id/extend-service-account-token" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{"duration": "'"$duration"'"}'`

echo "$result" | jq .

echo $result >> $NUON_ACTIONS_OUTPUT_FILEPATH
