#!/usr/bin/env bash
#
# verify-slack
#
# Verifies the install's Slack service is up after enable/sync:
#   1. the api-slack deployment has at least one ready pod in NAMESPACE, and
#   2. https://slack.$ROOT_DOMAIN resolves and serves an HTTP response.
#
# Required env:
#   ROOT_DOMAIN  - the install's root domain (slack service is at slack.$ROOT_DOMAIN).
#   NAMESPACE    - k8s namespace for ctl-api (default ctl-api).
#
# Writes an "indicator" output (🟢/🔴) and exits non-zero if either check fails.
set -uo pipefail

: "${NAMESPACE:=ctl-api}"

fail=0

# 1. api-slack pods ready
echo >&2 "checking api-slack pods in $NAMESPACE..."
READY=$(kubectl -n "$NAMESPACE" get pods -l app.nuon.co/name=ctl-api-slack \
  -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null \
  | grep -c "True")
if [[ "${READY:-0}" -ge 1 ]]; then
  echo >&2 "  ✅ $READY api-slack pod(s) ready"
else
  echo >&2 "  ❌ no ready api-slack pods found"
  fail=1
fi

# 2. slack.$ROOT_DOMAIN resolves and serves
HOST="slack.${ROOT_DOMAIN:-}"
echo >&2 "checking https://$HOST ..."
if [[ -z "${ROOT_DOMAIN:-}" ]]; then
  echo >&2 "  ❌ ROOT_DOMAIN is empty"
  fail=1
else
  # any HTTP response (incl. 4xx) means it resolves and serves; only DNS/connect
  # failure or 5xx counts as down.
  CODE=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 "https://$HOST/slack/oauth/callback" 2>/dev/null)
  if [[ -n "$CODE" && "$CODE" != "000" && "$CODE" -lt 500 ]]; then
    echo >&2 "  ✅ $HOST serves (HTTP $CODE)"
  else
    echo >&2 "  ❌ $HOST did not serve (HTTP ${CODE:-000})"
    fail=1
  fi
fi

if [[ "$fail" -eq 0 ]]; then indicator="🟢"; else indicator="🔴"; fi

echo >&2 "saving status to outputs..."
jq --null-input --arg indicator "$indicator" '{"indicator": $indicator}' >> "$NUON_ACTIONS_OUTPUT_FILEPATH"

echo >&2 "status is $indicator"
[[ "$fail" -eq 0 ]] || exit 1
