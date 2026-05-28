#!/usr/bin/env sh

set -e
set -o pipefail
set -u


admin_api_url="$ADMIN_API_URL"

echo "[reprovision] get orgs"
orgs=`curl -s "$admin_api_url/v1/orgs?type=default&limit=100" | jq -c`

for org_id in `echo $orgs | jq -r '.[].id'`; do
  echo " > reprovisioning: org id:$org_id"
  curl -s -X 'POST' \
    "$admin_api_url/v1/orgs/$org_id/admin-reprovision" \
    -H 'accept: application/json'         \
    -H 'Content-Type: application/json'   \
    -H 'X-Nuon-Admin-Email:jon@nuon.co' \
    -d '{}'
done
