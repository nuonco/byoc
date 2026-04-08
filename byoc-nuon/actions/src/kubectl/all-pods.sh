#!/usr/bin/env sh

set -e
set -o pipefail
set -u

kubectl get pods --all-namespaces
kubectl get pods --all-namespaces -o json | jq -c '{pods: [.items[] | {metadata: (.metadata | {name, namespace, creationTimestamp})}]}' >> $NUON_ACTIONS_OUTPUT_FILEPATH
