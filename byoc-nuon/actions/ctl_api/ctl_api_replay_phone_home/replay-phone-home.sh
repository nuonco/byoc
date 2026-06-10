#!/usr/bin/env bash
#
# POST a phone-home payload to the BYOC admin API. Use this when a phone-home
# request was missed and needs to be manually replayed.
#
# The endpoint is unauthenticated (it's normally called from the customer's AWS
# Lambda or Terraform local-exec), so we only need the URL + payload.
#
# Env vars:
#   ADMIN_API_URL    - templated base admin URL (set by the action TOML)
#   INSTALL_ID       - install id, e.g. inl_...
#   PHONE_HOME_PATH  - phone-home path segment from the original URL,
#                      e.g. "aws/..." (everything after /phone-home/)
#   PAYLOAD          - JSON object captured from install_stack_version_runs.data
#                      (the `data` field of a run from ctl_api_query_phone_home).
#                      request_type=Create is added automatically.

set -euo pipefail

: "${ADMIN_API_URL:?ADMIN_API_URL is required}"
: "${INSTALL_ID:?INSTALL_ID is required}"
: "${PHONE_HOME_PATH:?PHONE_HOME_PATH is required}"
: "${PAYLOAD:?PAYLOAD is required}"

url="${ADMIN_API_URL%/}/v1/installs/${INSTALL_ID}/phone-home/${PHONE_HOME_PATH#/}"

payload=$(echo "$PAYLOAD" | jq '. + {request_type: "Create"}')

echo "POST $url"
echo "payload:"
echo "$payload" | jq .
echo

resp_file=$(mktemp)
http_code=$(curl -sS -o "$resp_file" -w "%{http_code}" \
  -X POST "$url" \
  -H "Content-Type: application/json" \
  --data "$payload")

echo "HTTP $http_code"
echo "response:"
cat "$resp_file"
echo
rm -f "$resp_file"

if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
  exit 1
fi
