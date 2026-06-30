#!/usr/bin/env bash
#
# Fetches dashboard-ui /version and writes version + git_ref to action outputs.

set -e
set -o pipefail
set -u

# Fetch /version, retrying until it returns a valid JSON body. This step also
# runs post-deploy (right after dashboard_ui deploys), so the route is often not
# serving JSON yet: curl may return a 2xx with an HTML gateway/error page, or an
# empty body on a closed connection — both exit 0, so a bare `|| echo '{}'` does
# NOT catch them and `jq --argjson` then aborts with "invalid JSON text". Poll
# until the body parses as JSON, falling back to {} (→ "unknown") if it never does.
fetch_version() {
  attempts="${ATTEMPTS:-6}"
  i=1
  while true; do
    body=$(curl -sS --max-time 10 "${APP_URL}/version" || true)
    if printf '%s' "$body" | jq -e . >/dev/null 2>&1; then
      printf '%s' "$body"
      return 0
    fi
    if [ "$i" -ge "$attempts" ]; then
      echo "dashboard-ui /version did not return valid JSON after ${attempts} attempts; emitting unknown." >&2
      echo '{}'
      return 0
    fi
    echo "dashboard-ui /version not ready (attempt ${i}/${attempts}), retrying in 10s..." >&2
    i=$((i + 1))
    sleep 10
  done
}

resp=$(fetch_version)

jq -cn --argjson r "$resp" '{
  dashboard_ui_version: ($r.ui.version // $r.version // "unknown"),
  dashboard_ui_git_ref: ($r.ui.git_ref // $r.git_ref // "unknown"),
}' >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
