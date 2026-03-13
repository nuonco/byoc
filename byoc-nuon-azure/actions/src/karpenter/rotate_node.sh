#!/bin/bash
# rotates node in a nodepool by draininig and deleting it

set -e
set -o pipefail
set -u

node="$NODE_NAME"

# get the node info and store it for output
node_info=$(kubectl get node "$node" -o json | jq -c)

# drain the node
echo "Draining node: $node"
kubectl drain "$node" --ignore-daemonsets --delete-emptydir-data --force --timeout=300s

# delete the node
echo "Deleting node: $node"
kubectl delete node "$node"

# pipe the stored node info into the outputs
echo "$node_info" >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
