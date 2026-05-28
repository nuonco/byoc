#!/usr/bin/env bash

set -e
set -o pipefail
set -u

# user-configurable env vars that control options
refresh="$REFRESH"
org_id="$ORG_ID"
admin_api_addr="$ADMIN_API_URL"

# these are default env vars
region="$AWS_REGION"
install_id="$NUON_INSTALL_ID"


# preface
export AWS_PAGER=""

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

secret_name="$install_id/$org_id-sa-token"

# Check if secret exists and create/update accordingly
if aws secretsmanager describe-secret --secret-id "$secret_name" --region "$region" >/dev/null 2>&1; then
    echo "Secret exists, updating..."
    aws secretsmanager update-secret \
        --secret-id "$secret_name" \
        --secret-string "$api_token" \
        --region "$region"
else
    echo "Creating new secret..."
    aws secretsmanager create-secret \
        --name "$secret_name" \
        --secret-string "$api_token" \
        --tags Key="install.nuon.co/id",Value="$install_id" Key="source.nuon.co/type",Value="action" Key="source.nuon.co/name",Value="create_or_refresh_sa_token" \
        --region "$region"
fi

echo "Secret $secret_name has been created/updated successfully"

secret=`aws secretsmanager describe-secret --secret-id "$secret_name" --region "$region" | jq -c`

echo $secret >> $NUON_ACTIONS_OUTPUT_FILEPATH
