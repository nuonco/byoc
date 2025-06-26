#!/usr/bin/env bash

# make the db accessible from within the cluster

set -e
set -o pipefail
set -u

# always present
region="$REGION"
identifier="$IDENTIFIER"


sg_id=$(aws ec2 describe-security-groups \
    --region $region \
    --output json \
    | jq --arg key "Identifier" --arg value "nuon-$NUON_INSTALL_ID" \
    '.SecurityGroups[] | select(.Tags != null) | select(.Tags[] | (.Key == $key and .Value == $value))' \
    | jq -r '.GroupId')


aws --region "$region" ec2 describe-security-groups --group-ids "$sg_id"

aws --region $region rds modify-db-instance \
  --db-instance-identifier "$identifier" \
  --vpc-security-group-ids "$sg_id" \
  --master-user-password "$identifier" \
  --apply-immediately

