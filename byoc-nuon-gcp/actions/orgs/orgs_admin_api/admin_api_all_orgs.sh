#!/bin/bash

set -e
set -o pipefail
set -u

# set early so we fail fast if they're missing
endpoint_path="$ENDPOINT_PATH"
admin_api_url="$ADMIN_API_URL"
method="${METHOD:-POST}"
extra_headers="${EXTRA_HEADERS:-}"
# default value
admin_email="${ADMIN_EMAIL:-jon@nuon.co}"

body="${BODY:-}"
if [ -z "$body" ]; then
  body='{}'
fi

if [ "$endpoint_path" == "dne" ]; then
  echo "ENDPOINT_PATH must be set to an org admin API path, e.g. 'migrate-healthcheck-sweeps'"
  exit 1
fi

# strip any leading slash so both "foo" and "/foo" work
endpoint_path="${endpoint_path#/}"

# build up -H args from the comma separated EXTRA_HEADERS
header_args=()
if [ -n "$extra_headers" ]; then
  IFS=',' read -ra headers <<< "$extra_headers"
  for header in "${headers[@]}"; do
    header="$(echo "$header" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    if [ -n "$header" ]; then
      header_args+=(-H "$header")
    fi
  done
fi

# TODO: ensure pagination works with more than 100 orgs
org_ids=$(curl -s "$admin_api_url/v1/orgs?type=default&limit=100" -H 'accept: application/json' -H "X-Nuon-Admin-Email: $admin_email" | jq -r '.[].id')

for org_id in $org_ids; do
  echo "$method to $admin_api_url/v1/orgs/$org_id/${endpoint_path}"
  curl -X "$method" -s -q "$admin_api_url/v1/orgs/$org_id/${endpoint_path}" \
    -H 'accept: application/json' \
    -H "X-Nuon-Admin-Email: $admin_email" \
    -H 'Content-Type: application/json' \
    ${header_args[@]+"${header_args[@]}"} \
    -d "$body"
  echo
  sleep 1
done
