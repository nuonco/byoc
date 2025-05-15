#!/usr/bin/env bash

set -e
set -u

region="$REGION"
auth0_client_secret_arn="$AUTH0_CLIENT_SECRET_ARN"


# ensure we can read a secret
echo "[ctl_api init] kubectl auth whoami"
echo "pwd: "`pwd`
kubectl auth whoami

validated=""
# ensure we cannot read a secret
aws --region $region secretsmanager get-secret-value --secret-id="$auth0_client_secret_arn"
if [[ "$?" != "0"]]; then
  validated="true"
else
  validate="false"
fi
