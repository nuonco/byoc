#!/usr/bin/env bash

# NOTE: this script runs after a temporal component and can be invoked manually.
# it is intended to be safe to run multiple times and will explicitly set the namespace
# retentions in order to ensure configs don't drift.

set -e
set -o pipefail
set -u

DEFAULT_RETENTION="3d"
LONG_RETENTION="30d"

echo >&2 "ensuring namespaces"
echo >&2 " > default retention: $DEFAULT_RETENTION"
echo >&2 " > long retention:    $LONG_RETENTION"


function create_namespace() {
  local name="$1"
  local retention="$2"
  local description="$3"

  echo >&2 " > namespace: $name (retention: $retention)"
  kubectl -n temporal exec -i deployment/temporal-admintools -- \
    temporal operator namespace create \
         --namespace   "$name"         \
         --description "$description"  \
         --retention   "$retention"
}

function set_namespace_retention() {
  local name="$1"
  local retention="$2"

  echo >&2 " > updating namespace retention: $name -> $retention"
  kubectl -n temporal exec -i deployment/temporal-admintools -- \
    temporal operator namespace update \
         --namespace "$name"           \
         --retention "$retention"
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
)

# Namespaces that need a longer retention period.
declare -a long_namespaces=(
  "vcs"
  "emitters"
)

set +e
for namespace in "${default_namespaces[@]}"
do
  echo >&2 "ensuring namespace $namespace"
  create_namespace "$namespace" "$DEFAULT_RETENTION" "$namespace for byoc nuon"
  set_namespace_retention "$namespace" "$DEFAULT_RETENTION"
done

for namespace in "${long_namespaces[@]}"
do
  echo >&2 "ensuring namespace $namespace"
  create_namespace "$namespace" "$LONG_RETENTION" "$namespace for byoc nuon"
  set_namespace_retention "$namespace" "$LONG_RETENTION"
done
exit 0
