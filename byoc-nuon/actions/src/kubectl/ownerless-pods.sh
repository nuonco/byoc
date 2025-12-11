#!/usr/bin/env sh

set -e
set -o pipefail
set -u

kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.metadata.ownerReferences == null) | .metadata | "\(.namespace)/\(.name)"'
kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.metadata.ownerReferences == null) | .metadata ' >> $NUON_ACTIONS_OUTPUT_FILEPATH
