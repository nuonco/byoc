#!/usr/bin/env bash

# NOTE: this script deletes and recreates Temporal namespaces. it is DESTRUCTIVE -
# any in-flight workflow history in the affected namespace(s) will be lost.
# if the NAMESPACE env var is set, only that namespace is reset. otherwise all
# namespaces are reset.

set -uo pipefail

DEFAULT_RETENTION="3d"
LONG_RETENTION="30d"

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

function delete_namespace() {
  local name="$1"

  echo >&2 " > deleting namespace: $name"
  kubectl -n temporal exec -i deployment/temporal-admintools -- \
    temporal operator namespace delete \
         --namespace "$name"           \
         --yes
}

function create_namespace() {
  local name="$1"
  local retention="$2"
  local description="$3"

  echo >&2 " > creating namespace: $name (retention: $retention)"
  kubectl -n temporal exec -i deployment/temporal-admintools -- \
    temporal operator namespace create \
         --namespace   "$name"         \
         --description "$description"  \
         --retention   "$retention"
}

function retention_for() {
  local name="$1"
  for ns in "${long_namespaces[@]}"; do
    if [[ "$ns" == "$name" ]]; then
      echo "$LONG_RETENTION"
      return
    fi
  done
  echo "$DEFAULT_RETENTION"
}

TARGET_NAMESPACE="${NAMESPACE:-}"

if [[ -n "$TARGET_NAMESPACE" ]]; then
  found=false
  for ns in "${default_namespaces[@]}" "${long_namespaces[@]}"; do
    if [[ "$ns" == "$TARGET_NAMESPACE" ]]; then
      found=true
      break
    fi
  done
  if [[ "$found" == "false" ]]; then
    echo >&2 "unknown namespace: $TARGET_NAMESPACE"
    echo >&2 "valid namespaces: ${default_namespaces[*]} ${long_namespaces[*]}"
    exit 1
  fi
  declare -a namespaces=("$TARGET_NAMESPACE")
else
  declare -a namespaces=("${default_namespaces[@]}" "${long_namespaces[@]}")
fi

echo >&2 "resetting namespaces: ${namespaces[*]}"

for namespace in "${namespaces[@]}"
do
  retention="$(retention_for "$namespace")"
  echo >&2 "resetting namespace $namespace (retention: $retention)"
  delete_namespace "$namespace" || echo >&2 " > delete failed (namespace may not exist), continuing"
  create_namespace "$namespace" "$retention" "$namespace for byoc nuon"
done

exit 0
