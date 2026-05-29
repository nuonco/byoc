#!/bin/bash

set -e
set -o pipefail
set -u


# set early so we fail fast if it's missing
endpoint="$ENDPOINT"
admin_api_url="$ADMIN_API_URL"
# default value
admin_email='jon@nuon.co'

# TODO: ensure pagination works with more than 100 orgs
org_ids=$(curl -s "$admin_api_url/v1/orgs?type=default&limit=100" -H 'accept: application/json' -H "X-Nuon-Admin-Email: $admin_email" | jq -r '.[].id')

for org_id in $org_ids; do
  echo "POST to $admin_api_url/v1/orgs/$org_id/${endpoint}"
  curl -X 'POST' -s -q "$admin_api_url/v1/orgs/$org_id/${endpoint}"  \
    -H 'accept: application/json' \
    -H "X-Nuon-Admin-Email: $admin_email" \
    -H 'Content-Type: application/json' \
    -d '{}'
  sleep 1
done
