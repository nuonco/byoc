#!/usr/bin/env sh

set -e
set -o pipefail
set -u

admin_api_url="$ADMIN_API_URL"
runner_id="$RUNNER_ID"

outputs='{}'

echo "extending runner token"

OUTPUT=$(curl -s \
  --max-time 5 \
  -q \
  -X 'POST' \
  "$admin_api_url/v1/runners/$runner_id" \
  --data '{"duration":"8760h"}')

outputs=$(echo "$OUTPUT" | jq '{email: .email, expires_at: .expires_at}')
echo "$outputs" >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
