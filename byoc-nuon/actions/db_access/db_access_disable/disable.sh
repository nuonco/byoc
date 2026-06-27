#!/usr/bin/env bash

set -euo pipefail

# Injected by the role-disabled trigger: ROLE_NAME, ROLE_ARN, ROLE_TYPE, CHANGE_TYPE.
# When run manually those vars won't be set, so require them explicitly.
: "${ROLE_NAME:?ROLE_NAME is required}"
: "${ROLE_ARN:?ROLE_ARN is required}"

# Guard: only act on the db-access role.
if [[ "$ROLE_NAME" != *"-db-access" ]]; then
  echo "skipping: ROLE_NAME=$ROLE_NAME is not a db-access role"
  exit 0
fi

echo "[db-access disable] deleting access entry for $ROLE_ARN on cluster $CLUSTER_NAME"
aws eks delete-access-entry \
  --region "$REGION" \
  --cluster-name "$CLUSTER_NAME" \
  --principal-arn "$ROLE_ARN"

echo "[db-access disable] done"
