#!/usr/bin/env bash

# Polls the app (dashboard-ui) route over HTTP until it serves a healthy
# response. Runs as a dashboard_ui post-deploy hook so a fresh provision does NOT
# complete — and a human does not land — while the route is still in its
# post-deploy window returning 5xx or an Envoy "fault filter abort". Unlike the
# route-resource healthcheck (which only checks HTTPRoute Accepted/ResolvedRefs
# conditions), this makes a real request, so it catches serving-time faults.
#
# Healthy = curl succeeds AND status is 2xx-4xx (the app's normal unauthenticated
# response is a 302 redirect to auth; 401/403 also mean "up") AND the body is not
# "fault filter abort". 5xx, connection failures, and the abort body all retry.
#
# Read-only; curl only, no cloud role.
#
# Env:
#   APP_URL   the app URL to poll (https://app.<public_domain>)
#   ATTEMPTS  max attempts, 10s apart (default 30 = ~5m)

set -u

url="${APP_URL:?APP_URL required}"
attempts="${ATTEMPTS:-30}"

body="$(mktemp)"
trap 'rm -f "$body"' EXIT

i=1
while true; do
  code=$(curl -s --max-time 10 -o "$body" -w '%{http_code}' "$url")
  rc=$?
  abort=false
  if grep -qi 'fault filter abort' "$body" 2>/dev/null; then
    abort=true
  fi

  if [ "$rc" -eq 0 ] && [ "${code:-0}" -ge 200 ] && [ "${code:-0}" -lt 500 ] && [ "$abort" = false ]; then
    echo "app route serving (http ${code}) after attempt ${i}."
    exit 0
  fi

  if [ "$abort" = true ]; then
    reason="fault filter abort (http ${code})"
  elif [ "$rc" -ne 0 ]; then
    reason="curl exit ${rc}"
  else
    reason="http ${code}"
  fi

  if [ "$i" -ge "$attempts" ]; then
    echo "ERROR: app route ${url} did not become healthy after ${attempts} attempts (~5m). Last: ${reason}." >&2
    echo "last body (first 200 chars): $(head -c 200 "$body" | tr '\n' ' ')" >&2
    exit 1
  fi

  echo "app route not ready yet (attempt ${i}/${attempts}, ${reason}), retrying in 10s..."
  i=$((i + 1))
  sleep 10
done
