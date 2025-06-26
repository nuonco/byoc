#!/usr/bin/env bash

set -e
set -o pipefail
set -u

secret_arn="$DB_SECRET_ARN"
region="$REGION"
source_identifier="$SOURCE_IDENTIFIER"
target_host="$TARGET_HOST"
dry_run="${DRY_RUN:-true}"

echo "[restore] kubectl auth whoami"
echo "pwd: "`pwd`
kubectl auth whoami -o json | jq -c

echo "[restore] scale up the deployment"
kubectl scale -n ctl-api --replicas=1 deployment/ctl-api-init
kubectl wait deployment -n ctl-api ctl-api-init --for condition=Available=True --timeout=300s

echo "[restore] get a pod from the deployment"
pod=`kubectl -n ctl-api get pods --selector app=ctl-api-init -o json | jq -r '.items[0].metadata.name'`

echo "[restore] reading db access secrets from AWS"
secret=`aws --region $region secretsmanager get-secret-value --secret-id=$secret_arn`
admin_username=`echo $secret | jq -r '.SecretString' | jq -r '.username'`
admin_password=`echo $secret | jq -r '.SecretString' | jq -r '.password'`


echo "[restore] describe source"
aws --region $region rds describe-db-instances --filters "Name=db-instance-id,Values=$source_identifier" | jq
SOURCE_HOST=`aws --region $region rds describe-db-instances --filters "Name=db-instance-id,Values=$source_identifier" | jq -r '.DBInstances.[0].Endpoint.Address'`

echo "[restore] describe source sg"
sg_id=`aws --region $region rds describe-db-instances --filters "Name=db-instance-id,Values=$source_identifier" | jq -r '.DBInstances.[0].VpcSecurityGroups.[0].VpcSecurityGroupId'`
aws --region "$region" ec2 describe-security-groups --group-ids "$sg_id"


echo "[restore] ensure connectivity to target"
kubectl \
  --namespace=ctl-api \
  exec  -i \
  $pod -- \
  env "TARGET_HOST=$target_host" "PGUSER=$admin_username" "PGPASSWORD=$admin_password" \
  sh -c 'psql -h $TARGET_HOST -d nuonadmin -c "select 1"'

echo "[restore] ensure connectivity to source"
echo " > SOURCE_HOST: $SOURCE_HOST"
kubectl \
  --namespace=ctl-api \
  exec  -i \
  $pod -- \
  env "SOURCE_HOST=$SOURCE_HOST" "PGPASSWORD=$source_identifier" \
  sh -c 'nslookup $SOURCE_HOST; psql -h $SOURCE_HOST -U nuon -d ctl_api -c "select 1;"'

echo "[restore] pg_dump source"
echo " > SOURCE_HOST: $SOURCE_HOST"
kubectl \
  --namespace=ctl-api \
  exec  -i \
  $pod -- \
  env "SOURCE_HOST=$SOURCE_HOST" "PGPASSWORD=$source_identifier" \
  sh -c 'pg_dump -h $SOURCE_HOST -U nuon -d ctl_api > /tmp/ctl-api'

echo "[restore] some facts"
kubectl \
  --namespace=ctl-api \
  exec  -i \
  $pod -- \
  sh -c 'ls /tmp/ctl-api && head -n 4 /tmp/ctl-api && du /tmp/ctl-api'

echo "[restore] preparing to copy"
echo " > SOURCE_HOST: $SOURCE_HOST"
echo " > TARGET_HOST: $target_host"

if [[ "$dry_run" == "false" ]]; then
  set +e # allowed to fail
  kubectl \
    --namespace=ctl-api \
    exec  -i \
    $pod -- \
    env "TARGET_HOST=$target_host" "PGUSER=$admin_username" "PGPASSWORD=$admin_password" \
    sh -c 'psql -h $TARGET_HOST -d nuonadmin -c "CREATE DATABASE ctl_api;"' # only works once
  set -e

  kubectl \
    --namespace=ctl-api \
    exec  -i \
    $pod -- \
    env "TARGET_HOST=$target_host" "PGUSER=$admin_username" "PGPASSWORD=$admin_password" \
    sh -c 'psql -h $TARGET_HOST -d ctl_api < /tmp/ctl-api'

else
  echo '[dry-run] psql -h $TARGET_HOST -d ctl_api < /tmp/ctl-api'
fi

echo "[restore] scale down the deployment"
kubectl scale -n ctl-api --current-replicas=1 --replicas=0 deployment/ctl-api-init
