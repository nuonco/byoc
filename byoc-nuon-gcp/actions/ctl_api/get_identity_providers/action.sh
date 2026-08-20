#!/usr/bin/env bash
#
# List the identity providers configured on this control plane.
#
# Covers both sources: the provider configured through NUON_AUTH_* environment
# variables (reported with source "env", no database row, cannot be disabled
# through the API) and any number configured in the database.

set -e
set -o pipefail
set -u

admin_api_addr="$ADMIN_API_URL"

# no X-Nuon-Admin-Email: the identity-provider routes are plain internal routes, and
# a header that does not resolve against this install's accounts table is a 403.
providers=$(curl -sS -f -H 'accept: application/json' \
  "$admin_api_addr/v1/auth/identity-providers")

printf '%-28s %-8s %-22s %-10s %s\n' ID TYPE NAME SOURCE ENABLED
echo "$providers" | jq -r '
  .[] | [
    .id,
    .provider_type,
    (.name // "-"),
    (.source // "database"),
    (.enabled | tostring)
  ] | @tsv' | while IFS=$'\t' read -r id type name source enabled; do
  printf '%-28s %-8s %-22s %-10s %s\n' "$id" "$type" "$name" "$source" "$enabled"
done

echo "$providers" | jq -c '{count: length, providers: [.[] | {id, provider_type, name, enabled, source}]}' \
  >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
