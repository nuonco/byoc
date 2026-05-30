#!/usr/bin/env bash

# NOTE: This is an extremely destructive script to only be used after temporal is in a non-recoverable state.

set -e
set -o pipefail
set -u

function drop_namespace() {
  local name="$1"
  local description="$3"

  echo >&2 " > namespace: $name (retention: $retention)"
  kubectl -n temporal exec -i deployment/temporal-admintools -- \
    temporal operator namespace delete \
         --namespace   "$name"
}

# Namespaces that use the default short retention.
declare -a default_namespaces=(
  "general"
  "orgs"
  "apps"
  "installs"
  "runners"
  "actions"
  "components"
  "releases"
  "app-branches"
  "onboardings"
  "vcs"
  "emitters"
)

set +e
for namespace in "${default_namespaces[@]}"
do
  echo >&2 "dropping namespace $namespace"
  drop_namespace "$namespace"
done

exit 0
