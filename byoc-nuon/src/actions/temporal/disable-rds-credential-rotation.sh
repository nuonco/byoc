#!/usr/bin/env bash

set -e
set -o pipefail
set -u

# disable the pager
export AWS_PAGER=""

# grab instances
echo "looking for qualifying instances"
instances=`aws rds describe-db-instances --filters="Name=db-instance-id,Values=temporal-$NUON_INSTALL_ID" | jq '.DBInstances'`
count=`echo $instances | jq length`

# ensure one, and only one, exists
if [[ "$count" == 0 ]]; then
  echo "count should be 1, tbh"
  exit
elif [[ "$count" != 1 ]]; then
  echo "found more than one, this is unexpected"
  exit
fi

instance=`echo $instances | jq '.[0]'`
echo "updating secret for "`echo $instance | jq '.DBInstanceIdentifier'`
master_user_secret_arn=`echo $instance | jq -r '.MasterUserSecret.SecretArn'`
echo " > secret arn: $master_user_secret_arn"
aws secretsmanager cancel-rotate-secret --secret-id $master_user_secret_arn
