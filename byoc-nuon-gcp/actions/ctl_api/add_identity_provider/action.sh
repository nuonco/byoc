#!/usr/bin/env bash
#
# Add an identity provider to this control plane, or update it in place if one
# with the same client_id already exists.
#
# Several providers of the same type may coexist (ctl-api #2239), so identity is
# matched on client_id. Matching on provider_type instead would overwrite an
# unrelated provider that happens to share the type — that is how the removed
# nuon_access_enable action behaved, and why it was replaced.
#
# Required:
#   CLIENT_ID, CLIENT_SECRET
# Optional:
#   PROVIDER_TYPE   oidc (default) | google | github
#   PROVIDER_NAME   label on the sign-in button; defaults to a type-derived name
#   ISSUER_URL      required for oidc; the API runs discovery against it
#   AUTH_URL        overrides the authorization endpoint discovery would supply.
#                   Use it to pin provider-specific query params -- e.g. Auth0
#                   sends the user to its own login page unless the authorize URL
#                   names a connection, so
#                   https://<tenant>/authorize?connection=<name> makes the button
#                   go straight to the upstream IdP. Token and userinfo endpoints
#                   still come from discovery.
#   REDIRECT_URL    defaults to this install's own auth callback
#   ENABLED         true (default) | false
#   ALLOW_ALL_USERS unset (default) inherits nuon_auth_allow_all_users; true|false
#                   overrides it for this provider only

set -e
set -o pipefail
set -u

admin_api_addr="$ADMIN_API_URL"

: "${CLIENT_ID:?CLIENT_ID is required}"
: "${CLIENT_SECRET:?CLIENT_SECRET is required}"
: "${REDIRECT_URL:?REDIRECT_URL is required}"
: "${PROVIDER_TYPE:=oidc}"
: "${ENABLED:=true}"

created=false
id=""
enabled=false
# ok stays false unless the API call succeeds, so a failed run cannot be misread
# as a successful one by anything consuming the outputs file
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

case "$PROVIDER_TYPE" in
  oidc)
    config_key="openid_config"
    : "${ISSUER_URL:?ISSUER_URL is required for the oidc provider type}"
    ;;
  google) config_key="google_config" ;;
  github) config_key="github_config" ;;
  *)
    echo >&2 "[idp] error: unsupported provider type: $PROVIDER_TYPE"
    exit 1
    ;;
esac

config=$(jq -cn \
  --arg cid "$CLIENT_ID" \
  --arg secret "$CLIENT_SECRET" \
  --arg redirect "$REDIRECT_URL" \
  '{client_id: $cid, client_secret: $secret, redirect_url: $redirect}')

if [[ "$PROVIDER_TYPE" == "oidc" ]]; then
  config=$(echo "$config" | jq -c --arg issuer "$ISSUER_URL" '.issuer_url = $issuer')
  if [[ -n "${AUTH_URL:-}" ]]; then
    config=$(echo "$config" | jq -c --arg au "$AUTH_URL" '.auth_url = $au')
  fi
fi

body=$(jq -cn \
  --arg pt "$PROVIDER_TYPE" \
  --argjson enabled "$ENABLED" \
  --arg ck "$config_key" \
  --argjson config "$config" \
  '{provider_type: $pt, enabled: $enabled} + {($ck): $config}')

if [[ -n "${PROVIDER_NAME:-}" ]]; then
  body=$(echo "$body" | jq -c --arg name "$PROVIDER_NAME" '.name = $name')
fi

# only send allow_all_users when explicitly set; omitting it leaves the provider
# inheriting the deployment-wide flag.
if [[ -n "${ALLOW_ALL_USERS:-}" ]]; then
  body=$(echo "$body" | jq -c --argjson aau "$ALLOW_ALL_USERS" '.allow_all_users = $aau')
fi

url="$admin_api_addr/v1/auth/identity-providers"

echo "[idp] looking for an existing provider with client_id=$CLIENT_ID"
providers=$(curl -sS -f -H 'accept: application/json' "$url")
existing_id=$(echo "$providers" | jq -r --arg cid "$CLIENT_ID" \
  'map(select(.client_id == $cid)) | (.[0].id // "")')

if [[ -n "$existing_id" ]]; then
  # the env-configured provider has no database row, so it cannot be patched
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
  echo "[idp] creating $PROVIDER_TYPE provider"
  # for oidc the API performs discovery against issuer_url and returns 400 when it
  # cannot reach it; check egress from the cluster to the issuer if that happens.
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
