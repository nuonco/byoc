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
admin_db="nuonadmin"

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
    psql --no-psqlrc -d "$admin_db" -c "$@"
}

function dothis(){
  echo " > cmd: $@"
}

echo "[ctl_api init] enable hstore"
run_cmd "CREATE EXTENSION IF NOT EXISTS hstore;"

echo "[ctl_api init] ensuring user & db"

# this can fail on subsequent runs
set +e
run_cmd "CREATE USER ctl_api WITH LOGIN;"
set -e

run_cmd "GRANT rds_iam TO ctl_api; GRANT CREATE TO ctl_api; CREATE DATABASE ctl_api; GRANT rds_iam TO ctl_api;"
