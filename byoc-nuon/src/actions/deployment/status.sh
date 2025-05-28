#!/usr/bin/env bash

set -e
set -o pipefail
set -u

# TODO: add sleep between
# TODO: write output
name="$DEPLOYMENT_NAME"
namespace="$DEPLOYMENT_NAMESPACE"

echo >&2 "checking deployment statuses"
kubectl get -n $namespace deployment -o wide

echo >&2 "checking deployment pod statuses"
kubectl get -n $namespace deployment -o json | \
 jq -r '.items[].metadata.name'           | \
 cut -d '-' -f 2                          | \
 xargs -I % kubectl get -n temporal pods -l="app.kubernetes.io/component=%" -o wide
