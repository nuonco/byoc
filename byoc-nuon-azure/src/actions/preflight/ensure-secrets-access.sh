#!/usr/bin/env bash

set -e
set -o pipefail
set -u

secret_namespace="$SECRET_NAMESPACE"
secret_name="$SECRET_NAME"

echo "[preflight] checking secret exists: $secret_namespace/$secret_name"

exists="false"
if kubectl get secret -n "$secret_namespace" "$secret_name" >/dev/null 2>&1; then
  exists="true"
fi

results=$(jq -nc --arg namespace "$secret_namespace" --arg name "$secret_name" --arg exists "$exists" '{
  secret_namespace: $namespace,
  secret_name: $name,
  exists: ($exists == "true"),
  note: "Azure migration: secret-manager IAM denial checks are not applicable"
}')

echo "$results"
echo "$results" >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
