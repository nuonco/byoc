#!/usr/bin/env bash
#
# Add an identity provider to this control plane, or update it in place if one
# with the same client_id already exists.
#
# The provider config is read from AWS Secrets Manager at runtime and never passes
# through an action input. Action env vars are persisted on the action run and
# rendered in the dashboard, so a client secret supplied that way would be stored
# and displayed to anyone who can see the install's action history.
#
# On AWS the install's maintenance role is granted on the secret directly, so the
# ambient credentials are used. SECRETS_ROLE_ARN is only needed where the runner has
# no AWS identity of its own (GCP), and is left unset here.
#
# The secret holds the create-request body:
#
#   {
#     "provider_type": "oidc",
#     "name": "Microsoft",
#     "openid_config": {
#       "client_id": "...",
#       "client_secret": "...",
#       "issuer_url": "https://<tenant>/",
#       "auth_url": "https://<tenant>/authorize?connection=<name>"
#     }
#   }
#
# redirect_url is deliberately NOT read from the secret. It is templated from this
# install's own DNS, so it follows a root_domain change instead of going stale --
# a hand-written redirect in the secret is what silently broke SSO once before.
#
# auth_url is optional and overrides the authorization endpoint discovery supplies.
# Auth0 sends users to its own login page unless the authorize URL names a
# connection, so pinning it there makes the button go straight to the upstream IdP.
#
# Several providers of the same type may coexist, so an existing provider is matched
# on client_id. Matching on provider_type would overwrite an unrelated provider that
# happens to share the type.
#
# Required env:
#   ADMIN_API_URL         - internal admin API base URL
#   PROVIDER_SECRET_ARN   - ARN of the secret holding the payload above
#   REDIRECT_URL          - this install's auth callback (templated)
# Optional env:
#   SECRETS_ROLE_ARN      - AWS role to assume via web identity (GCP)
#   SECRETS_AUDIENCE      - OIDC audience the role's trust policy expects
#   INSTALL_ID            - used for the STS role session name
#   ENABLED               - true (default) | false
#   ALLOW_ALL_USERS       - unset inherits nuon_auth_allow_all_users; true|false
#                           overrides it for this provider only

set -e
set -o pipefail
set -u

export AWS_PAGER=""

admin_api_url="$ADMIN_API_URL"

: "${PROVIDER_SECRET_ARN:?PROVIDER_SECRET_ARN is required -- the provider config is read from Secrets Manager, not from action inputs}"
: "${REDIRECT_URL:?REDIRECT_URL is required}"
: "${SECRETS_AUDIENCE:=sts.amazonaws.com}"
: "${ENABLED:=true}"

created=false
id=""
enabled=false
ok=false

write_outputs() {
  jq -cn \
    --argjson ok "$ok" \
    --argjson created "$created" \
    --arg id "$id" \
    --argjson enabled "$enabled" \
    --arg updated_at "$(TZ=UTC date +%Y-%m-%dT%H:%M:%SZ)" \
    '{ok: $ok, created: $created, id: $id, enabled: $enabled, updated_at: $updated_at}' \
    >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
}
trap write_outputs EXIT

# the region is embedded in the arn: arn:aws:secretsmanager:<region>:<acct>:secret:<name>
region=$(echo "$PROVIDER_SECRET_ARN" | cut -d: -f4)
region="${region:-us-west-2}"

if [[ -n "${SECRETS_ROLE_ARN:-}" ]]; then
  echo "[idp] minting identity token (audience: $SECRETS_AUDIENCE)"
  web_identity_token=$(curl -sf -H "Metadata-Flavor: Google" \
    "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity?audience=${SECRETS_AUDIENCE}&format=full")
  if [[ -z "$web_identity_token" ]]; then
    echo >&2 "[idp] failed to mint an identity token from the metadata server"
    exit 1
  fi

  echo "[idp] assuming $SECRETS_ROLE_ARN via web identity"
  creds=$(aws --region "$region" sts assume-role-with-web-identity \
    --role-arn "$SECRETS_ROLE_ARN" \
    --role-session-name "idp-${INSTALL_ID:-nuon}" \
    --web-identity-token "$web_identity_token" \
    --query 'Credentials' --output json)

  AWS_ACCESS_KEY_ID=$(echo "$creds" | jq -er '.AccessKeyId')
  AWS_SECRET_ACCESS_KEY=$(echo "$creds" | jq -er '.SecretAccessKey')
  AWS_SESSION_TOKEN=$(echo "$creds" | jq -er '.SessionToken')
  export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
fi

echo "[idp] reading provider config from Secrets Manager ($region)"
payload=$(aws --region "$region" secretsmanager get-secret-value \
  --secret-id "$PROVIDER_SECRET_ARN" \
  --query SecretString --output text)

if [[ -z "$payload" || "$payload" == "None" ]]; then
  echo >&2 "[idp] error: secret $PROVIDER_SECRET_ARN is empty"
  exit 1
fi
if ! echo "$payload" | jq -e . >/dev/null 2>&1; then
  echo >&2 "[idp] error: secret $PROVIDER_SECRET_ARN does not contain valid JSON"
  exit 1
fi

# determine the provider type and its config key: prefer an explicit provider_type,
# otherwise infer from whichever *_config key is present.
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
    echo >&2 "[idp] error: secret has no provider_type and no recognised *_config block."
    echo >&2 "[idp] expected {\"provider_type\": \"oidc\", \"openid_config\": {...}} -- older"
    echo >&2 "[idp] secrets predating this format need updating."
    exit 1
    ;;
esac

client_id=$(echo "$payload" | jq -r --arg ck "$config_key" '.[$ck].client_id // ""')
client_secret_present=$(echo "$payload" | jq -r --arg ck "$config_key" '(.[$ck].client_secret // "") | length > 0')
if [[ -z "$client_id" || "$client_secret_present" != "true" ]]; then
  echo >&2 "[idp] error: secret is missing $config_key.client_id or $config_key.client_secret"
  exit 1
fi
if [[ "$provider_type" == "oidc" ]]; then
  issuer=$(echo "$payload" | jq -r '.openid_config.issuer_url // ""')
  if [[ -z "$issuer" ]]; then
    echo >&2 "[idp] error: secret is missing openid_config.issuer_url (required for oidc)"
    exit 1
  fi
fi

echo "[idp] provider_type=$provider_type client_id=$client_id"

# build the request from the secret: force enabled, and always take redirect_url from
# this install's templated value rather than whatever the secret happens to hold.
body=$(echo "$payload" | jq -c \
  --argjson enabled "$ENABLED" \
  --arg ck "$config_key" \
  --arg redirect "$REDIRECT_URL" \
  '.enabled = $enabled | .[$ck].redirect_url = $redirect')

if [[ -n "${ALLOW_ALL_USERS:-}" ]]; then
  body=$(echo "$body" | jq -c --argjson aau "$ALLOW_ALL_USERS" '.allow_all_users = $aau')
fi

url="$admin_api_url/v1/auth/identity-providers"

# no X-Nuon-Admin-Email: these are plain internal routes, and a header that does not
# resolve against this install's accounts table is a 403.
echo "[idp] looking for an existing provider with this client_id"
providers=$(curl -sS -f -H 'accept: application/json' "$url")
existing_id=$(echo "$providers" | jq -r --arg cid "$client_id" \
  'map(select(.client_id == $cid)) | (.[0].id // "")')

if [[ -n "$existing_id" ]]; then
  if [[ "$existing_id" == default-* ]]; then
    echo >&2 "[idp] error: client_id matches the env-configured provider ($existing_id)."
    echo >&2 "[idp] change it through the install's NUON_AUTH_* inputs instead."
    exit 1
  fi

  echo "[idp] provider exists (id=$existing_id), updating"
  response=$(curl -sS -f -X PATCH \
    -H 'accept: application/json' -H 'Content-Type: application/json' \
    -d "$body" "$url/$existing_id")
  created=false
else
  echo "[idp] creating $provider_type provider"
  # for oidc the API runs discovery against issuer_url and returns 400 when it cannot
  # reach it; check egress from the cluster to the issuer if that happens.
  response=$(curl -sS -f -X POST \
    -H 'accept: application/json' -H 'Content-Type: application/json' \
    -d "$body" "$url")
  created=true
fi

id=$(echo "$response" | jq -r '.id // ""')
enabled=$(echo "$response" | jq -r '.enabled // false')
ok=true
echo "[idp] provider: created=$created id=$id enabled=$enabled"

echo "[idp] providers now configured:"
curl -sS -f -H 'accept: application/json' "$url" \
  | jq -r '.[] | "  \(.provider_type)\t\(.id)\t\(.name // "-")\t\(.source // "database")\tenabled=\(.enabled)"'
