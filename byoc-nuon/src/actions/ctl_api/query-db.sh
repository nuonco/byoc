#!/usr/bin/env bash

set -e
set -o pipefail
set -u

db_name="$DB_NAME"
db_user="$DB_USER"
db_addr="$DB_ADDR"
db_port="$DB_PORT"
region="$REGION"
secret_arn="$SECRET_ARN"
query="$QUERY"

# TODO: make the cluster's default/admin db and the ctl-api db distinct

echo "[ctl_api query] kubectl auth whoami"
echo "pwd: "`pwd`
kubectl auth whoami -o json | jq -c


echo "[ctl_api query] scale up the deployment"
kubectl scale -n ctl-api --replicas=1 deployment/ctl-api-init
kubectl wait deployment -n ctl-api ctl-api-init --for condition=Available=True --timeout=300s

echo "[ctl_api query] get a pod from the deployment"
pod=`kubectl -n ctl-api get pods --selector app=ctl-api-init -o json | jq -r '.items[0].metadata.name'`

echo "[ctl_api query] reading db access secrets from AWS"
secret=`aws --region $region secretsmanager get-secret-value --secret-id=$secret_arn`
admin_username=`echo $secret | jq -r '.SecretString' | jq -r '.username'`
admin_password=`echo $secret | jq -r '.SecretString' | jq -r '.password'`

echo "[ctl_api query] sanity check"
echo "these two should match"
echo "db_user=$db_user"
echo "username=$admin_username"

echo "[ctl_api query] preparing to initialize"
function execute_query() {
  echo " > query: $1"
  kubectl \
    --namespace=ctl-api \
    exec  -i \
    $pod -- \
    env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$admin_username" "PGPASSWORD=$admin_password" \
    psql --no-psqlrc -d "ctl_api" -c "$1"
}
# sleep so logs have time to flush?
sleep 1

execute_query "$query"

echo "[ctl_api query] scale down the deployment"
kubectl scale -n ctl-api --current-replicas=1 --replicas=0 deployment/ctl-api-init
