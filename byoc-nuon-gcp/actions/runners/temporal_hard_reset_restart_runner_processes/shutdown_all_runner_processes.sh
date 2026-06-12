#!/usr/bin/env bash

set -e
set -o pipefail
set -u

admin_api_url="$ADMIN_API_URL"

echo "[restart-runner-processes] forcing shutdown of all runner processes"
curl -s -X 'POST' \
  "$admin_api_url/v1/runners/shutdown-processes" \
  -H 'accept: application/json' \
  -H 'X-Nuon-Admin-Email: jon@nuon.co' \
  -H 'Content-Type: application/json' \
  -d '{"shutdown_type": "force"}'

echo
echo "[restart-runner-processes] done; runner deployments should respawn processes"
