#!/usr/bin/env bash

# Probes each public ctl-api/dashboard route and reports status, the serving
# proxy, and whether the response is an Envoy "fault filter abort" (an HTTP
# fault-injection filter aborting the request before it reaches the backend).
# Read-only; curl only, no cloud role.
#
# Prints a human-readable report to logs AND writes a structured result to
# NUON_ACTIONS_OUTPUT_FILEPATH ({"routes":[{name,url,code,server,fault}, ...]})
# so the runbook README can render it.
#
# Env:
#   PUBLIC_DOMAIN    public domain (app/api/auth/runner are subdomains)
#   INTERNAL_DOMAIN  internal domain (admin is a subdomain; VPC-only, http)

set -u

pub="${PUBLIC_DOMAIN:?PUBLIC_DOMAIN required}"
intd="${INTERNAL_DOMAIN:?INTERNAL_DOMAIN required}"

hdr="$(mktemp)"
body="$(mktemp)"
trap 'rm -f "$hdr" "$body"' EXIT

results='[]'

check() {
  name="$1"
  url="$2"
  echo ""
  echo "=== ${name}: ${url} ==="
  code=$(curl -s --max-time 10 -D "$hdr" -o "$body" -w '%{http_code}' "$url")
  rc=$?
  server=""
  fault=false
  if [ "$rc" -ne 0 ]; then
    case "$rc" in
      6)  code="dns-fail" ; echo "  curl exit 6: DNS does not resolve" ;;
      7)  code="refused"  ; echo "  curl exit 7: connection refused" ;;
      28) code="timeout"  ; echo "  curl exit 28: timed out (no/slow response)" ;;
      *)  code="err-${rc}"; echo "  curl failed (exit ${rc})" ;;
    esac
  else
    server=$(grep -i '^server:' "$hdr" | tr -d '\r' | cut -d' ' -f2-)
    echo "  http_code: ${code}"
    echo "  server:    ${server}"
    if grep -qi 'fault filter abort' "$body"; then
      fault=true
      echo "  >> FAULT FILTER ABORT — an Envoy fault-injection filter is aborting this route."
    fi
    echo "  body (first 200 chars): $(head -c 200 "$body" | tr '\n' ' ')"
  fi
  results=$(printf '%s' "$results" | jq -c \
    --arg n "$name" --arg u "$url" --arg c "${code:-}" --arg s "$server" --argjson f "$fault" \
    '. + [{name:$n, url:$u, code:$c, server:$s, fault:$f}]')
}

echo "Probing public routes on ${pub} and admin on ${intd}..."
check "app"    "https://app.${pub}"
check "api"    "https://api.${pub}/v1/general/healthz"
check "auth"   "https://auth.${pub}"
check "runner" "https://runner.${pub}"
check "admin"  "http://admin.${intd}/v1/general/healthz"

echo ""
echo "Interpreting:"
echo "  - 'fault filter abort' on a route => fault injection is configured on it;"
echo "    run the 'Locate fault injection' step to find and remove it."
echo "  - all routes abort => mesh-wide / shared-gateway fault."
echo "  - DNS/timeout (not abort) => a routing/LB problem, not fault injection."

printf '%s' "$results" | jq -c '{routes: .}' >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
