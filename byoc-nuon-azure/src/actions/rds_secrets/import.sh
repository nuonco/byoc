#!/usr/bin/env bash

set -e
set -o pipefail
set -u

username="$DB_USERNAME"
password="$DB_PASSWORD"
name="$TARGET_NAME"
namespace="$TARGET_NAMESPACE"

echo "[rds-secrets import] kubectl auth whoami"
echo "pwd: "`pwd`
kubectl auth whoami -o json | jq -c

echo "[rds-secrets import] create DB access secret from component outputs"
kubectl create -n $namespace secret generic $name \
  --save-config    \
  --dry-run=client \
  --from-literal=username="$username" \
  --from-literal=password="$password" \
  -o yaml | kubectl apply -f -
