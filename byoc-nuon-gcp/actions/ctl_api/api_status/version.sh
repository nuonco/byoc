#!/usr/bin/env bash
#
# Fetches ctl-api /version and writes version + git_ref to action outputs.

set -e
set -o pipefail
set -u

resp=$(curl -sS --max-time 10 "${API_URL}/version" || echo '{}')

jq -cn --argjson r "$resp" '{
  ctl_api_version: ($r.version // "unknown"),
  ctl_api_git_ref: ($r.git_ref // "unknown"),
}' >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
