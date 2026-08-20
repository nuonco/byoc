#!/usr/bin/env bash
#
# Update an existing identity provider: rename it, enable/disable it, or change
# its access policy. Use ctl_api_add_identity_provider to change credentials.
#
# Disabling removes the provider's button from the sign-in page. Existing sessions
# keep working until they expire, and the account_identities rows are left alone,
# so re-enabling restores access without anyone re-linking.
#
# Identify the provider by either:
#   IDENTITY_PROVIDER_ID  the row id, as shown by ctl_api_get_identity_providers
#   CLIENT_ID             matched against the configured client_id
#
# Optional (only the ones you set are sent):
#   PROVIDER_NAME    label on the sign-in button
#   ENABLED          true | false
#   ALLOW_ALL_USERS  true | false — overrides nuon_auth_allow_all_users for this
#                    provider. false means a user needs an existing account or a
#                    pending org invite.

set -e
set -o pipefail
set -u

admin_api_addr="$ADMIN_API_URL"
url="$admin_api_addr/v1/auth/identity-providers"

id="${IDENTITY_PROVIDER_ID:-}"
enabled=false
# ok stays false unless the patch succeeds, so a refused or failed run cannot be
# misread as a successful one by anything consuming the outputs file
ok=false

write_outputs() {
  jq -cn \
    --argjson ok "$ok" \
    --arg id "$id" \
    --argjson enabled "$enabled" \
    --arg updated_at "$(TZ=UTC date +%Y-%m-%dT%H:%M:%SZ)" \
    '{ok: $ok, id: $id, enabled: $enabled, updated_at: $updated_at}' \
    >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
}
trap write_outputs EXIT

if [[ -z "$id" ]]; then
  if [[ -z "${CLIENT_ID:-}" ]]; then
    echo >&2 "[idp] error: set IDENTITY_PROVIDER_ID or CLIENT_ID"
    exit 1
  fi
  echo "[idp] resolving provider by client_id=$CLIENT_ID"
  id=$(curl -sS -f -H 'accept: application/json' "$url" \
    | jq -r --arg cid "$CLIENT_ID" 'map(select(.client_id == $cid)) | (.[0].id // "")')
  if [[ -z "$id" ]]; then
    echo >&2 "[idp] error: no provider found with client_id=$CLIENT_ID"
    exit 1
  fi
fi

if [[ "$id" == default-* ]]; then
  echo >&2 "[idp] error: $id is the env-configured provider and has no database row."
  echo >&2 "[idp] change it through the install's NUON_AUTH_* inputs instead."
  exit 1
fi

body='{}'
[[ -n "${PROVIDER_NAME:-}" ]]   && body=$(echo "$body" | jq -c --arg n "$PROVIDER_NAME" '.name = $n')
[[ -n "${ENABLED:-}" ]]         && body=$(echo "$body" | jq -c --argjson e "$ENABLED" '.enabled = $e')
[[ -n "${ALLOW_ALL_USERS:-}" ]] && body=$(echo "$body" | jq -c --argjson a "$ALLOW_ALL_USERS" '.allow_all_users = $a')

if [[ "$body" == "{}" ]]; then
  echo >&2 "[idp] error: nothing to update — set PROVIDER_NAME, ENABLED or ALLOW_ALL_USERS"
  exit 1
fi

echo "[idp] patching $id with $body"
response=$(curl -sS -f -X PATCH \
  -H 'accept: application/json' -H 'Content-Type: application/json' \
  -d "$body" "$url/$id")

enabled=$(echo "$response" | jq -r '.enabled // false')
ok=true
echo "[idp] updated:"
echo "$response" | jq -r '{id, provider_type, name, enabled}'
