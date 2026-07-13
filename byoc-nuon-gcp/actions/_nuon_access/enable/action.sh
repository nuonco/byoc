#!/usr/bin/env bash
#
# nuon_access_enable (GCP)
#
# Reads the central Nuon Access secret (an identity provider payload) from the
# central AWS Secrets Manager (byoc-infra-prod), upserts an enabled identity
# provider on the Auth service via the admin API, then appends nuon.co to the
# ctl-api configmap's NUON_AUTH_ALLOWED_DOMAINS and restarts ctl-api-auth.
#
# Unlike the AWS install (whose maintenance IAM role is granted on the secret
# directly), a GCP install has no AWS identity. Instead it federates: the
# runner mints a Google-signed OIDC token for its GCP identity via the GCE/GKE
# metadata server and exchanges it for temporary AWS credentials via
# sts:AssumeRoleWithWebIdentity against a per-install reader role in
# byoc-infra-prod (same flow as sync_slack_secrets).
#
# Required env:
#   ADMIN_API_URL           - internal admin API base URL.
#   NUON_ACCESS_SECRET_ARN  - full ARN of the central secret. Empty => skip (no-op).
#   NUON_ACCESS_ROLE_ARN    - AWS IAM role to assume via web identity.
#   NUON_ACCESS_AUDIENCE    - OIDC audience the role's trust policy expects.
#   NAMESPACE               - k8s namespace for ctl-api (default ctl-api).
#   INSTALL_ID              - used for the STS role session name.

set -e
set -o pipefail
set -u

export AWS_PAGER=""

: "${NAMESPACE:=ctl-api}"
: "${NUON_ACCESS_AUDIENCE:=sts.amazonaws.com}"

# admin api. the identity-provider endpoints are plain internal routes: the
# X-Nuon-Admin-Email header is optional audit-only and must be omitted here --
# a fresh control plane has no nuon.co accounts yet, and a header that fails to
# resolve is a 403.
admin_api_url="$ADMIN_API_URL"
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

if [[ -z "${NUON_ACCESS_ROLE_ARN:-}" ]]; then
  echo >&2 "[nuon-access] NUON_ACCESS_ROLE_ARN is empty; cannot federate into AWS to read the secret"
  exit 1
fi

# the region is embedded in the secret arn: arn:aws:secretsmanager:<region>:<acct>:secret:<name>
region=$(echo "$nuon_access_secret_arn" | cut -d: -f4)
region="${region:-us-west-2}"

# mint a Google-signed OIDC identity token for this runner's GCP identity and
# exchange it for temporary AWS credentials (no pre-existing AWS creds needed).
echo "[nuon-access] minting GCP identity token (audience: $NUON_ACCESS_AUDIENCE)"
web_identity_token=$(curl -sf -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity?audience=${NUON_ACCESS_AUDIENCE}&format=full")
if [[ -z "$web_identity_token" ]]; then
  echo >&2 "[nuon-access] failed to mint GCP identity token from the metadata server"
  exit 1
fi

echo "[nuon-access] assuming AWS role via web identity"
echo "  role:   $NUON_ACCESS_ROLE_ARN"
echo "  region: $region"
creds=$(aws --region "$region" sts assume-role-with-web-identity \
  --role-arn "$NUON_ACCESS_ROLE_ARN" \
  --role-session-name "nuon-access-${INSTALL_ID:-nuon}" \
  --web-identity-token "$web_identity_token" \
  --query 'Credentials' --output json)

export AWS_ACCESS_KEY_ID=$(echo "$creds" | jq -er '.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$creds" | jq -er '.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$creds" | jq -er '.SessionToken')

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
  "$url")

existing_id=$(echo "$identity_providers" | jq -r \
  --arg pt "$provider_type" \
  'map(select(.provider_type == $pt)) | (.[0].id // "")')

# the request body is the full secret payload with enabled forced to true. this way updating
# the secret (e.g. the redirect url) propagates to the db on the next run, and we only ever
# override the enabled flag.
body=$(echo "$payload" | jq -c '.enabled = true')

if [[ -n "$existing_id" ]]; then
  # provider exists: PATCH it by id with the secret payload, enabling it
  echo "[nuon-access] provider exists (id=$existing_id), updating and enabling"
  response=$(curl -sS -f -X PATCH \
    -H 'accept: application/json' \
    -H 'Content-Type: application/json' \
    -d "$body" \
    "$url/$existing_id")
  created=false
else
  # provider does not exist: POST the secret payload, always forcing enabled=true
  echo "[nuon-access] provider does not exist, creating"
  response=$(curl -sS -f -X POST \
    -H 'accept: application/json' \
    -H 'Content-Type: application/json' \
    -d "$body" \
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

current_domains=$(kubectl get -n "$NAMESPACE" configmap "ctl-api" \
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
  kubectl patch -n "$NAMESPACE" configmap "ctl-api" \
    --type merge \
    -p "{\"data\":{\"$cm_key\":\"$updated_domains\"}}"

  # the configmap is consumed via envFrom across the split ctl-api deployments
  # (ctl-api-auth, -public, -admin, ...); env changes only take effect on restart,
  # so roll the auth deployment to pick up the new value.
  echo "[nuon-access] restarting ctl-api-auth deployment"
  kubectl rollout restart -n "$NAMESPACE" deployment/ctl-api-auth
fi

echo "[nuon-access] done"
