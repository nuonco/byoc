#!/usr/bin/env bash
#
# Fetches dashboard-ui /version and writes version + git_ref to action outputs.

set -e
set -o pipefail
set -u

resp=$(curl -sS --max-time 10 "${APP_URL}/version" || echo '{}')

jq -cn --argjson r "$resp" '{
  dashboard_ui_version: ($r.ui.version // $r.version // "unknown"),
  dashboard_ui_git_ref: ($r.ui.git_ref // $r.git_ref // "unknown"),
}' >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
