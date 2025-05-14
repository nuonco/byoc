#!/usr/bin/env bash

set -e
set -o pipefail
set -u

region="$REGION"
secret_arn="$SECRET_ARN"
name="$TARGET_NAME"
namespace="$TARGET_NAMESPACE"

echo "[rds-secrets import] kubectl auth whoami"
echo "pwd: "`pwd`
kubectl auth whoami

echo "[rds-secrets import] reading db access secrets from AWS"
secret=`aws --region $region secretsmanager get-secret-value --secret-id=$secret_arn`
username=`echo $secret | jq -r '.SecretString' | jq -r '.username'`
password=`echo $secret | jq -r '.SecretString' | jq -r '.password'`


kubectl create -n ctl-api secret generic clickhouse-cluster-pw \
  --save-config    \
  --dry-run=client \
  --from-literal=value="$password" \
  -o yaml | kubectl apply -f -

kubectl create -n $namespace secret generic $name \
  --save-config    \
  --dry-run=client \
  --from-literal=username="$username" \
  --from-literal=password="$password" \
  -o yaml | kubectl apply -f -
