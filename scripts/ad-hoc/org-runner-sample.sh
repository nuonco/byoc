#!/usr/bin/env bash

set -e
set -o pipefail
set -u

# List all deployments (across all namespaces) with `runner-` in the name,
# pick one at random, and print its full JSON spec compacted via jq -c
# so it can be copy/pasted from the logs.

mapfile -t deployments < <(
  kubectl get deployments --all-namespaces \
    -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' \
  | grep ' .*runner-'
)

if [ "${#deployments[@]}" -eq 0 ]; then
  echo "No deployments matching 'runner-' found." >&2
  exit 1
fi

echo "Found ${#deployments[@]} runner- deployments:"
printf '  %s\n' "${deployments[@]}"

pick="${deployments[$((RANDOM % ${#deployments[@]}))]}"
ns="${pick%% *}"
name="${pick##* }"

echo
echo "Randomly selected: namespace=$ns deployment=$name"
echo

kubectl -n "$ns" get deployment "$name" -o json | jq -c
