#!/usr/bin/env bash
#
# Emits `{updated_at: <ISO8601 UTC>}` to the action outputs so the runbook
# can render the time its data was last refreshed.

set -euo pipefail

jq -nc --arg ts "$(TZ=UTC date +%Y-%m-%dT%H:%M:%SZ)" '{updated_at: $ts}' \
  >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
