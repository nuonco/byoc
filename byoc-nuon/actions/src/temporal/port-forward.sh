#!/usr/bin/env bash

# this action requires the break glass role.
# it port-forwards the temporal frontend so the caller can hit temporal
# directly from the CLI, e.g.:
#   temporal --address localhost:7233 --namespace general workflow list
# the forward runs until the action timeout (see temporal_expose.toml).

set -e
set -o pipefail
set -u

namespace="${TEMPORAL_NAMESPACE:-temporal}"
service="${TEMPORAL_SERVICE:-temporal-frontend-headless}"
local_port="${LOCAL_PORT:-7233}"
remote_port="${REMOTE_PORT:-7233}"

# record who opened the forward, so the action output captures the break-glass identity.
kubectl auth whoami -o json | jq -c '{ break_glass_identity: . }'

jq -cn \
  --arg ns "$namespace" \
  --arg svc "$service" \
  --argjson lp "$local_port" \
  --argjson rp "$remote_port" \
  '{ port_forward: { namespace: $ns, service: $svc, local_port: $lp, remote_port: $rp } }' \
  >> "$NUON_ACTIONS_OUTPUT_FILEPATH"

echo >&2 "port-forwarding ${namespace}/${service} :${remote_port} -> localhost:${local_port}"
echo >&2 "hit it with: temporal --address localhost:${local_port} --namespace <ns> ..."

exec kubectl -n "$namespace" port-forward "service/${service}" "${local_port}:${remote_port}"
