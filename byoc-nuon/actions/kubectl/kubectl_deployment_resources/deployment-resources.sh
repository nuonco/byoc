#!/usr/bin/env bash

# emits per-deployment resource requests/limits, current top usage per pod,
# and any OOMKilled containers as a single json blob to the action output.
# env:
#   NAMESPACE - namespace to inspect (default: ctl-api)

set -euo pipefail

: "${NAMESPACE:=ctl-api}"

echo "namespace=${NAMESPACE}"

workdir=$(mktemp -d)
trap 'rm -rf "${workdir}"' EXIT

kubectl -n "${NAMESPACE}" get deployments -o json > "${workdir}/deployments.json"
kubectl -n "${NAMESPACE}" get pods -o json > "${workdir}/pods.json"

# kubectl top may fail if metrics-server is unhealthy; fall back to empty usage.
kubectl -n "${NAMESPACE}" top pods --no-headers 2>/dev/null \
  | awk 'NF>=3 {printf "{\"name\":\"%s\",\"cpu\":\"%s\",\"memory\":\"%s\"}\n", $1, $2, $3}' \
  | jq -s '.' > "${workdir}/top.json" || echo '[]' > "${workdir}/top.json"

result=$(jq -c \
  --slurpfile pods "${workdir}/pods.json" \
  --slurpfile top "${workdir}/top.json" \
  '($pods[0]) as $pods
   | ($top[0]) as $top
   | {namespace: env.NAMESPACE, deployments: [.items[] as $d
    | ($d.spec.selector.matchLabels // {}) as $sel
    | ($pods.items
        | map(select(
            (.metadata.labels // {}) as $labels
            | ($sel | to_entries | all(.value == $labels[.key]))
          ))
      ) as $deployment_pods
    | {
        deployment: $d.metadata.name,
        replicas: $d.spec.replicas,
        ready_replicas: ($d.status.readyReplicas // 0),
        containers: [$d.spec.template.spec.containers[] | {
          name: .name,
          requests: (.resources.requests // {}),
          limits: (.resources.limits // {})
        }],
        pods: [$deployment_pods[] | . as $pod | {
          name: $pod.metadata.name,
          phase: $pod.status.phase,
          restart_count: ([(($pod.status.containerStatuses // [])[]).restartCount] | add // 0),
          oom_killed: ([
            ($pod.status.containerStatuses // [])[]
            | select((.lastState.terminated.reason // "") == "OOMKilled"
                  or (.state.terminated.reason // "") == "OOMKilled")
          ] | length > 0),
          oom_containers: [
            ($pod.status.containerStatuses // [])[]
            | select((.lastState.terminated.reason // "") == "OOMKilled"
                  or (.state.terminated.reason // "") == "OOMKilled")
            | .name
          ],
          usage: ($top | map(select(.name == $pod.metadata.name)) | .[0] // null)
        }]
      }
   ]}' "${workdir}/deployments.json")

echo "${result}" | jq
echo "${result}" >> "${NUON_ACTIONS_OUTPUT_FILEPATH}"
