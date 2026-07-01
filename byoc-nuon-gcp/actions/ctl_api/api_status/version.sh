#!/usr/bin/env bash
#
# Fetches ctl-api /version and writes version + git_ref to action outputs.

set -e
set -o pipefail
set -u

# Fetch /version, retrying until it returns a valid JSON body. This step also
# runs post-deploy (right after ctl-api deploys), so the API is often not serving
# JSON yet: curl may return a 2xx with an HTML gateway/error page, or an empty
# body on a closed connection — both exit 0, so a bare `|| echo '{}'` does NOT
# catch them and `jq --argjson` then aborts with "invalid JSON text". Poll until
# the body parses as JSON, falling back to {} (→ "unknown") if it never does.
fetch_version() {
  attempts="${ATTEMPTS:-6}"
  i=1
  while true; do
    body=$(curl -sS --max-time 10 "${API_URL}/version" || true)
    if printf '%s' "$body" | jq -e . >/dev/null 2>&1; then
      printf '%s' "$body"
      return 0
    fi
    if [ "$i" -ge "$attempts" ]; then
      echo "ctl-api /version did not return valid JSON after ${attempts} attempts; emitting unknown." >&2
      echo '{}'
      return 0
    fi
    echo "ctl-api /version not ready (attempt ${i}/${attempts}), retrying in 10s..." >&2
    i=$((i + 1))
    sleep 10
  done
}

resp=$(fetch_version)

jq -cn --argjson r "$resp" '{
  ctl_api_version: ($r.version // "unknown"),
  ctl_api_git_ref: ($r.git_ref // "unknown"),
}' >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
