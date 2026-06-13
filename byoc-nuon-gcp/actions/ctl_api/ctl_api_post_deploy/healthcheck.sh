#!/usr/bin/env sh

set -e
set -o pipefail
set -u

route_name="${ROUTE_NAME:-${INGRESS_NAME:-}}"
route_namespace="${ROUTE_NAMESPACE:-${INGRESS_NAMESPACE:-}}"

if [ -z "$route_name" ] || [ -z "$route_namespace" ]; then
  echo >&2 "route name/namespace not set (ROUTE_NAME/ROUTE_NAMESPACE)"
  exit 1
fi

echo >&2 "checking httproute ${route_name} in ${route_namespace}..."

route_json=$(kubectl get --namespace "$route_namespace" httproute "$route_name" -o json)

hostname=$(echo "$route_json" | jq -r '.spec.hostnames[0] // "unknown"')
gateway=$(echo "$route_json" | jq -r '.spec.parentRefs[0].name // "unknown"')
gateway_namespace=$(echo "$route_json" | jq -r '.spec.parentRefs[0].namespace // .metadata.namespace')

accepted=$(echo "$route_json" | jq -r '[.status.parents[]?.conditions[]? | select(.type=="Accepted") | .status] | (length > 0) and (all(. == "True"))')
resolved=$(echo "$route_json" | jq -r '[.status.parents[]?.conditions[]? | select(.type=="ResolvedRefs") | .status] | (length > 0) and (all(. == "True"))')

if [ "$accepted" = "true" ] && [ "$resolved" = "true" ]; then
  indicator="🟢"
else
  indicator="🔴"
fi

gateway_address=$(kubectl get --namespace "$gateway_namespace" gateway "$gateway" -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || echo "unknown")

jq -cn \
  --arg hn "$hostname" \
  --arg gw "$gateway" \
  --arg addr "$gateway_address" \
  --arg accepted "$accepted" \
  --arg resolved "$resolved" \
  --arg indicatorVar "$indicator" \
  '{indicator: $indicatorVar, hostname: $hn, gateway: $gw, gateway_address: $addr, accepted: $accepted, resolved_refs: $resolved}' \
  >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
