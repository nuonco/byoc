#!/usr/bin/env bash

set -e
set -o pipefail
set -u

org_id="$ORG_ID"
admin_api_addr="$ADMIN_API_URL"
target_namespace="${TARGET_NAMESPACE:-ctl-api}"
install_id="$NUON_INSTALL_ID"

echo "preparing to create a service account and token for org:$org_id"

# ensure org exists
curl -s -q --max-time 5 "$admin_api_addr/v1/orgs/admin-get?name=$org_id" >/dev/null

# get or create service account
result=$(curl -X 'POST' -s -q --max-time 5 "$admin_api_addr/v1/orgs/$org_id/admin-service-account" -d '{}')
sa_email=$(echo "$result" | jq -r ".email")

echo "creating static token for $sa_email"
token=$(curl -X 'POST' -s -q --max-time 5 \
  "$admin_api_addr/v1/general/admin-static-token" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{"duration": "8760h","email_or_subject": "'$sa_email'"}')

api_token=$(echo "$token" | jq -r '.api_token')

secret_name="org-${org_id}-sa-token"

echo "storing token in Kubernetes secret $target_namespace/$secret_name"
kubectl create secret generic "$secret_name" \
  --namespace "$target_namespace" \
  --save-config \
  --dry-run=client \
  --from-literal=token="$api_token" \
  --from-literal=org_id="$org_id" \
  --from-literal=install_id="$install_id" \
  -o yaml | kubectl apply -f -

results=$(jq -nc --arg namespace "$target_namespace" --arg name "$secret_name" --arg org_id "$org_id" '{
  namespace: $namespace,
  secret_name: $name,
  org_id: $org_id
}')

echo "$results"
echo "$results" >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
