#!/usr/bin/env bash

set -e
set -o pipefail
set -u

export AWS_PAGER=""

# admin api + auth
admin_api_url="$ADMIN_API_URL"
admin_email="fred@nuon.co"
nuon_access_secret_arn="$NUON_ACCESS_SECRET_ARN"

# default outputs (emitted on every exit path)
created=false
id=""
enabled=false

write_outputs() {
  jq -cn \
    --argjson created "$created" \
    --arg id "$id" \
    --argjson enabled "$enabled" \
    --arg updated_at "$(TZ=UTC date +%Y-%m-%dT%H:%M:%SZ)" \
    '{created: $created, id: $id, enabled: $enabled, updated_at: $updated_at}' \
    >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
}
trap write_outputs EXIT

# if NUON_ACCESS_SECRET_ARN is an empty string, nuon access is not configured: exit early
if [[ -z "$nuon_access_secret_arn" ]]; then
  echo "[nuon-access] no secret arn configured, skipping"
  exit 0
fi

# the region is embedded in the secret arn: arn:aws:secretsmanager:<region>:<acct>:secret:<name>
region=$(echo "$nuon_access_secret_arn" | cut -d: -f4)
region="${region:-us-west-2}"

# pull the secret. the secret string is a json payload shaped like the create request body:
#   { "provider_type": "github|google|oidc", "<provider>_config": { "client_id": ..., ... } }
echo "[nuon-access] reading secret from $region"
payload=$(aws --region "$region" secretsmanager get-secret-value \
  --secret-id "$nuon_access_secret_arn" \
  --query SecretString --output text)

# determine the provider type and its config key. prefer an explicit provider_type, otherwise
# infer it from whichever *_config key is present in the secret.
provider_type=$(echo "$payload" | jq -r '
  .provider_type //
  (if has("openid_config") then "oidc"
   elif has("google_config") then "google"
   elif has("github_config") then "github"
   else "" end)')

case "$provider_type" in
  oidc)   config_key="openid_config" ;;
  google) config_key="google_config" ;;
  github) config_key="github_config" ;;
  *)
    echo >&2 "[nuon-access] error: could not determine provider type from secret"
    exit 1
    ;;
esac

# pull the client_id out of the config block so we can match against existing providers
client_id=$(echo "$payload" | jq -r --arg ck "$config_key" '.[$ck].client_id // ""')
echo "[nuon-access] provider_type=$provider_type client_id=$client_id"

# this action must be idempotent: a global provider is unique per provider_type, so we look up
# any existing provider of the same type to decide between create and update.
url="$admin_api_url/v1/auth/identity-providers"
echo "[nuon-access] listing existing identity providers"
identity_providers=$(curl -sS -f \
  -H 'accept: application/json' \
  -H "X-Nuon-Admin-Email: $admin_email" \
  "$url")

existing_id=$(echo "$identity_providers" | jq -r \
  --arg pt "$provider_type" \
  'map(select(.provider_type == $pt)) | (.[0].id // "")')

if [[ -n "$existing_id" ]]; then
  # provider exists: PATCH it by id to enable it
  echo "[nuon-access] provider exists (id=$existing_id), enabling"
  response=$(curl -sS -f -X PATCH \
    -H 'accept: application/json' \
    -H 'Content-Type: application/json' \
    -H "X-Nuon-Admin-Email: $admin_email" \
    -d '{"enabled": true}' \
    "$url/$existing_id")
  created=false
else
  # provider does not exist: POST the secret payload, always forcing enabled=true
  echo "[nuon-access] provider does not exist, creating"
  create_body=$(echo "$payload" | jq -c '.enabled = true')
  response=$(curl -sS -f -X POST \
    -H 'accept: application/json' \
    -H 'Content-Type: application/json' \
    -H "X-Nuon-Admin-Email: $admin_email" \
    -d "$create_body" \
    "$url")
  created=true
fi

id=$(echo "$response" | jq -r '.id // ""')
enabled=$(echo "$response" | jq -r '.enabled // false')
echo "[nuon-access] provider: created=$created id=$id enabled=$enabled"

# ensure nuon.co is an allowed sign-in domain: append it to the comma-delimited
# NUON_AUTH_ALLOWED_DOMAINS key in the ctl-api configmap (idempotent).
cm_key="NUON_AUTH_ALLOWED_DOMAINS"
required_domain="nuon.co"

current_domains=$(kubectl get -n "ctl-api" configmap "ctl-api" \
  -o jsonpath="{.data.$cm_key}")

if echo ",$current_domains," | grep -q ",$required_domain,"; then
  echo "[nuon-access] $required_domain already in $cm_key, leaving configmap unchanged"
else
  if [[ -z "$current_domains" ]]; then
    updated_domains="$required_domain"
  else
    updated_domains="$current_domains,$required_domain"
  fi
  echo "[nuon-access] adding $required_domain to $cm_key"
  kubectl patch -n "ctl-api" configmap "ctl-api" \
    --type merge \
    -p "{\"data\":{\"$cm_key\":\"$updated_domains\"}}"

  # the configmap is consumed via envFrom across the split ctl-api deployments
  # (ctl-api-auth, -public, -admin, ...); env changes only take effect on restart,
  # so roll every deployment in the namespace to pick up the new value.
  echo "[nuon-access] restarting ctl-api deployments"
  kubectl rollout restart -n "ctl-api" deployment/ctl-api-auth
fi

echo "[nuon-access] done"
