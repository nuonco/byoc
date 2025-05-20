#!/usr/bin/env bash

set -u

region="$REGION"
auth0_client_secret_arn="$AUTH0_CLIENT_SECRET_ARN"


aws --region $region sts get-caller-identity

# ensure we can NOT read this specific secret
validated=""
echo "attempting to fetch secret: expected to fail"
aws --region $region secretsmanager get-secret-value --secret-id="$auth0_client_secret_arn"
exitCode=$?
if [ $exitCode -eq 0 ]; then
  echo "failed to fetch secret (exit code $exitCode)"
  exit 0
else
  echo "failed to fail to fetch secret"
  echo "review permissions.toml to ensure permissions are set appropriately."
  exit 1
fi
