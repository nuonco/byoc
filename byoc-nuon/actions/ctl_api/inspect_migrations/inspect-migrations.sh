#!/usr/bin/env bash
#
# Inspect ctl-api schema migrations via the admin API (GET /v1/general/migrations).
# Emits one JSON object per migration to $NUON_ACTIONS_OUTPUT_FILEPATH, keyed by
# "<created_at>_<id>" so the README map-range renders them oldest -> newest.
# Migrations run in sequence, so any error / in-progress migration is naturally
# the most recent (last) row. Limited to the last 10 by created_at.

set -e
set -o pipefail
set -u

admin_api_addr="$ADMIN_API_URL"

echo "[inspect_migrations] GET $admin_api_addr/v1/general/migrations"
migrations=$(curl --max-time 30 -s "$admin_api_addr/v1/general/migrations")

if ! echo "$migrations" | jq -e 'type == "array"' >/dev/null 2>&1; then
  echo "[inspect_migrations] expected JSON array, got: $migrations" >&2
  exit 1
fi

count=$(echo "$migrations" | jq 'length')
echo "[inspect_migrations] $count migration(s) returned"

echo "$migrations" | jq -c '
  [ .[] | { id, name, status: (.status // "unknown"), created_at, updated_at } ]
  | sort_by(.created_at)
  | .[-10:][]
  | { ("\(.created_at)_\(.id)"): . }
' >> "$NUON_ACTIONS_OUTPUT_FILEPATH"

echo "[inspect_migrations] done"
