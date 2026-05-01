#!/bin/bash

set -e
set -o pipefail
set -u


api_addr="http://api.{{ .nuon.sandbox.outputs.nuon_dns.public_domain.name }}"
admin_api_addr="http://admin.{{ .nuon.sandbox.outputs.nuon_dns.internal_domain.name }}"
admin_email='jon@nuon.co'

org_ids=$(curl -s "$admin_api_addr/v1/orgs?type=default&limit=100" -H 'accept: application/json' -H "X-Nuon-Admin-Email: $admin_email" | jq -r '.[].id')

for org_id in $org_ids; do
  echo "Patching Settings for $org_id"
  curl -X 'PATCH' -s -q "$admin_api_addr/v1/orgs/$org_id/admin-features" \
    -H 'accept: application/json' \
    -H "X-Nuon-Admin-Email: $admin_email" \
    -H 'Content-Type: application/json' \
    -d '{
      "features": {
        "parallel-runner-jobs": false,
        "app-branches": false,
        "queues": false
      }
    }'
  sleep 5
done
