#!/usr/bin/env bash

set -e
set -o pipefail
set -u

admin_api_addr="$ADMIN_API_URL"

# Fetch the migrations list from the admin API, retrying until it returns a valid
# JSON array. This step runs right after restart-deployments has rolled every
# ctl-api deployment (including ctl-api-admin), so on a fresh provision the admin
# API is often not back up yet — curl returns an empty/early body, and because
# the original `migrations=$(curl ... | jq -c)` is a command-substitution
# assignment, `set -e` does NOT catch the failure: `migrations` ends up empty and
# the later `jq --argjson` fails with "invalid JSON text passed to --argjson".
# Poll until the endpoint actually returns a JSON array instead.
fetch_migrations() {
  attempts=30
  i=1
  while true; do
    body=$(curl -s --max-time 10 "$admin_api_addr/v1/general/migrations" || true)
    if printf '%s' "$body" | jq -e 'type == "array"' >/dev/null 2>&1; then
      printf '%s' "$body" | jq -c
      return 0
    fi
    if [ "$i" -ge "$attempts" ]; then
      echo "ERROR: admin API did not return a valid migrations array after ${attempts} attempts (~5m)." >&2
      echo "last response: ${body:-<empty>}" >&2
      return 1
    fi
    echo "admin migrations endpoint not ready (attempt ${i}/${attempts}), retrying in 10s..." >&2
    i=$((i + 1))
    sleep 10
  done
}

echo "get ctl-api migrations data"
migrations=$(fetch_migrations)

echo "format migrations data"
echo "$migrations" | jq -r '.[] | "\(.created_at) \(.status) \(.name)"'
# -c: the outputs file is parsed one JSON object PER LINE, so this must be a
# single compact line. Without -c, jq pretty-prints multi-line and the runner
# fails parsing the first fragment ("unexpected end of JSON input").
outputs=$(jq -c --null-input --argjson migrationsVar "$migrations" '{"migrations": $migrationsVar}')

echo "save migrations data to outputs"
echo "$outputs" >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
