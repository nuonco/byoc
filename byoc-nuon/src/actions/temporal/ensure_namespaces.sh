#!/usr/bin/env bash

set -e
set -o pipefail
set -u

RETENTION="30d"

echo >&2 "ensuring namespaces"
echo >&2 " > retention: $RETENTION"


function create_namespace() {
  local name="$1"
  local retention="$2"
  local description="$3"

  echo >&2 " > namespace: $name"
  kubectl -n temporal exec -i deployment/temporal-admintools -- \
    temporal operator namespace create \
         --namespace   "$name"         \
         --description "$description"  \
         --retention   "$retention"
}

declare -a namespaces=("orgs" "apps" "installs" "components" "releases" "installers" "runners" "general" "actions")
echo >&2 "using $RETENTION day retention"

for namespace in "${namespaces[@]}"
do
  echo >&2 "creating namespace $namespace"
  create_namespace $namespace $RETENTION "$namespace for byoc nuon"
done
