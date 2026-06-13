#!/usr/bin/env sh

set -e
set -o pipefail
set -u

echo >&2 "checking httproute ${ROUTE_NAME} in ${ROUTE_NAMESPACE}..."

route_json=$(kubectl get --namespace "$ROUTE_NAMESPACE" httproute "$ROUTE_NAME" -o json)

hostname=$(echo "$route_json" | jq -r '.spec.hostnames[0] // "unknown"')
gateway=$(echo "$route_json" | jq -r '.spec.parentRefs[0].name // "unknown"')
gateway_namespace=$(echo "$route_json" | jq -r '.spec.parentRefs[0].namespace // .metadata.namespace')

# A route is serving traffic when its parent gateway reports both Accepted and
# ResolvedRefs = True. Empty conditions (not yet reconciled) count as unhealthy.
accepted=$(echo "$route_json" | jq -r '[.status.parents[]?.conditions[]? | select(.type=="Accepted") | .status] | (length > 0) and (all(. == "True"))')
resolved=$(echo "$route_json" | jq -r '[.status.parents[]?.conditions[]? | select(.type=="ResolvedRefs") | .status] | (length > 0) and (all(. == "True"))')

if [ "$accepted" = "true" ] && [ "$resolved" = "true" ]; then
  indicator="🟢"
else
  indicator="🔴"
fi

gateway_address=$(kubectl get --namespace "$gateway_namespace" gateway "$gateway" -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || echo "unknown")

outputs=$(jq --null-input \
  --arg hn "$hostname" \
  --arg gw "$gateway" \
  --arg addr "$gateway_address" \
  --arg accepted "$accepted" \
  --arg resolved "$resolved" \
  --arg indicatorVar "$indicator" \
  '{"indicator": $indicatorVar, "hostname": $hn, "gateway": $gw, "gateway_address": $addr, "accepted": $accepted, "resolved_refs": $resolved}')
echo "$outputs" >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
