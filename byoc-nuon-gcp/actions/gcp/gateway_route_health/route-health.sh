#!/usr/bin/env bash

# Shows the gateway, HTTPRoutes, and the backend pods behind the app/api routes.
# Use when a route returns DNS/timeout rather than "fault filter abort" — i.e. a
# routing or backend problem rather than fault injection. Read-only; kubectl
# only, no cloud role.
#
# Prints a human-readable report to logs AND writes a structured result to
# NUON_ACTIONS_OUTPUT_FILEPATH ({"httproutes":[{ns,name,hosts,backends}],
# "dashboard_pods_ready", "ctl_api_pods_ready"}) so the README can render it.

set -u

echo "==================================================================="
echo " Gateways"
echo "==================================================================="
kubectl get gateway -A 2>/dev/null || echo "  (no Gateway resources)"

echo ""
echo "==================================================================="
echo " HTTPRoutes (name, hostnames, parent gateway, backend)"
echo "==================================================================="
routes_json=$(kubectl get httproute -A -o json 2>/dev/null || echo '{"items":[]}')
printf '%s' "$routes_json" | jq -r '.items[] | "  \(.metadata.namespace)/\(.metadata.name)\n    hosts:    \(.spec.hostnames // [] | join(", "))\n    parents:  \([.spec.parentRefs[]?.name] | join(", "))\n    backends: \([.spec.rules[]?.backendRefs[]? | "\(.name):\(.port)"] | join(", "))"'

echo ""
echo "==================================================================="
echo " dashboard-ui backend pods (the 'app' route)"
echo "==================================================================="
kubectl get pods -A 2>/dev/null | grep -i dashboard || echo "  no dashboard-ui pods found"

echo ""
echo "==================================================================="
echo " ctl-api backend pods (api / auth / runner / admin routes)"
echo "==================================================================="
kubectl get pods -n ctl-api 2>/dev/null || echo "  ctl-api namespace not found"

echo ""
echo "Interpreting:"
echo "  - a route with no/incorrect backendRefs, or a backend with 0 ready pods,"
echo "    explains a timeout/5xx (NOT a 'fault filter abort')."
echo "  - if pods are healthy and routes look correct but a route still aborts,"
echo "    the cause is fault injection — use the 'Locate fault injection' step."

# ── structured outputs ───────────────────────────────────────────────────────
routes_out=$(printf '%s' "$routes_json" | jq -c '[.items[] | {
  ns: .metadata.namespace,
  name: .metadata.name,
  hosts: (.spec.hostnames // []),
  backends: [.spec.rules[]?.backendRefs[]? | "\(.name):\(.port)"]
}]')
dash_ready=$(kubectl get pods -A -o json 2>/dev/null | jq -r '[.items[] | select(.metadata.name | test("dashboard"; "i")) | select(.status.phase=="Running")] | length' 2>/dev/null || echo 0)
ctl_ready=$(kubectl get pods -n ctl-api -o json 2>/dev/null | jq -r '[.items[] | select(.status.phase=="Running")] | length' 2>/dev/null || echo 0)
jq -nc --argjson r "${routes_out:-[]}" --arg d "${dash_ready:-0}" --arg c "${ctl_ready:-0}" \
  '{httproutes:$r, dashboard_pods_ready:($d|tonumber), ctl_api_pods_ready:($c|tonumber)}' \
  >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
