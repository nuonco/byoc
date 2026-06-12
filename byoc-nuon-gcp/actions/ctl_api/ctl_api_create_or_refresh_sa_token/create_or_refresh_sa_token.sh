#!/usr/bin/env bash

set -e
set -o pipefail
set -u

# user-configurable env vars that control options
refresh="$REFRESH"
org_id="$ORG_ID"
admin_api_addr="$ADMIN_API_URL"

# these are default env vars
project_id="$PROJECT_ID"
install_id="$NUON_INSTALL_ID"

echo "preparing to create a service account and token for org:$org_id"

# ensure org exists
curl -s -q --max-time 5 \
  "$admin_api_addr/v1/orgs/admin-get?name=$org_id"

# get or create service account
result=`curl -X 'POST' -s -q --max-time 5 "$admin_api_addr/v1/orgs/$org_id/admin-service-account" -d '{}'`

sa_email=`echo $result | jq -r ".email"`

echo "Preparing to create token for Service Account for $sa_email"
token=$(curl -X 'POST' -s -q --max-time 5 \
  "$admin_api_addr/v1/general/admin-static-token" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{"duration": "8760h","email_or_subject": "'$sa_email'"}')

api_token=`echo $token | jq -r '.api_token'`

echo "Preparing to store token on Secret Manager"

# GCP Secret Manager ids cannot contain "/", so use "-" as the separator
secret_name="$install_id-$org_id-sa-token"

# Check if secret exists and create/add a version accordingly
if gcloud secrets describe "$secret_name" --project "$project_id" >/dev/null 2>&1; then
    echo "Secret exists, adding new version..."
    printf '%s' "$api_token" | gcloud secrets versions add "$secret_name" \
        --project "$project_id" \
        --data-file=-
else
    echo "Creating new secret..."
    printf '%s' "$api_token" | gcloud secrets create "$secret_name" \
        --project "$project_id" \
        --labels="install_nuon_co_id=$install_id,source_nuon_co_type=action,source_nuon_co_name=create_or_refresh_sa_token" \
        --data-file=-
fi

echo "Secret $secret_name has been created/updated successfully"

secret=`gcloud secrets describe "$secret_name" --project "$project_id" --format json | jq -c`

echo $secret >> $NUON_ACTIONS_OUTPUT_FILEPATH
