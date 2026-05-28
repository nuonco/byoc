#!/bin/bash
# rotates all of the nodes in a nodepool relatively forcefully by draining and deleting them all
#
set -e
set -o pipefail
set -u

nodepool="$NODEPOOL_NAME"

# use kubectl to get the nodepool
kubectl get nodepool "$nodepool" -o json | jq -c

# use kubectl to get each node in the nodepool
# store the nodes in a var so we can pass the json to the outputs
nodes=$(kubectl get nodes -l "karpenter.sh/nodepool=$nodepool" -o json | jq -c)
node_names=$(echo "$nodes" | jq -r '.items[].metadata.name')

# for each node, drain it (sleep 3s between nodes)
for node in $node_names; do
  echo "Draining node: $node"
  kubectl drain "$node" --ignore-daemonsets --delete-emptydir-data --force --timeout=300s
  sleep 3
done

# for each node, delete it
for node in $node_names; do
  echo "Deleting node: $node"
  kubectl delete node "$node"
done

# pipe the stored nodes into the outputs
echo "$nodes" >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
