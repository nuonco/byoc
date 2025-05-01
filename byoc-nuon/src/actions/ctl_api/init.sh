#!/usr/bin/env bash

set -e
set -o pipefail
set -u

db_addr="$DB_ADDR"
db_port="$DB_PORT"
region="$REGION"
secret_arn="$SECRET_ARN"

# TODO: make the cluster's default/admin db and the ctl-api db distinct

echo "[ctl_api init] kubectl auth whoami"
echo "pwd: "`pwd`
kubectl auth whoami


echo "[ctl_api init] reading db access secrets from AWS"
secret=`aws --region $region secretsmanager get-secret-value --secret-id=$secret_arn`
admin_username=`echo $secret | jq -r '.SecretString' | jq -r '.username'`
admin_password=`echo $secret | jq -r '.SecretString' | jq -r '.password'`
admin_db="ctl_api"

echo "[ctl_api init] preparing to initialize"
function run_cmd() {
  echo " > cmd: $@"
  kubectl \
    run   \
    --restart=Never      \
    --namespace=ctl-api \
    "psql-$(date +"%s")-$(openssl rand -hex 4)" \
    --image=postgres:15-alpine3.20     \
    --env="PGHOST=$db_addr"            \
    --env="PGPORT=$db_port"               \
    --env="PGUSER=$admin_username"           \
    --env="PGPASSWORD=$admin_password" \
    --command \
    -- \
    psql --no-psqlrc -c "$@"
}


echo "[ctl_api init] ensuring db"
run_cmd "GRANT rds_iam TO ctl_api;"


echo "[ctl_api init] enable hstore"
run_cmd "CREATE EXTENSION IF NOT EXISTS hstore;"
