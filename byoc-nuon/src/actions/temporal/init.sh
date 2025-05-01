#!/usr/bin/env bash

set -e
set -o pipefail
set -u


# re-assigning these vars so the script fails early if any are missing
address="$DB_HOST"
port="$DB_PORT"
secret_arn="$DB_SECRET_ARN"
install_id="$NUON_INSTALL_ID"
region="$REGION"
version="1.26.2"
cluster_name="$CLUSTER_NAME"
role="$ROLE"


# echo "[temporal init] updating kubeconfig"
# aws --region $region eks update-kubeconfig --name $cluster_name --alias $cluster_name --role-arn $role
# kubectl --v=9 config use-context $cluster_name
# export KUBECONFIG="/root/.kube/config"

echo "[temporal init] kubectl auth whoami"
echo "pwd: "`pwd`
kubectl auth whoami

# set later
user="nuonadmin i think"
password="wouldn't you like to know ... "

echo "[temporal init] reading db access secrets from AWS"
secret=`aws --region $region secretsmanager get-secret-value --secret-id=$secret_arn`
username=`echo $secret | jq -r '.SecretString' | jq -r '.username'`
password=`echo $secret | jq -r '.SecretString' | jq -r '.password'`


# TODO: re-write this so we can see the logs - maybe use exec
# # --rm -i -t \
function run_cmd() {
  echo " > cmd: $1"
  kubectl \
    run   \
    --restart=Never      \
    --namespace=temporal \
    "nuon-temporal-admintools-$(date +"%s")-$(openssl rand -hex 4)"  \
    --image=temporalio/admin-tools:"$version" \
    --env="SQL_HOST=$address"      \
    --env="SQL_PORT=$port"         \
    --env="SQL_USER=$username"     \
    --env="SQL_PASSWORD=$password" \
    --env="SQL_PLUGIN=postgres12"  \
    --env="VERSION=$version"       \
    --command \
    -- \
    $1
}

echo "[temporal init] creating the temporal database"
run_cmd "temporal-sql-tool --db temporal create"

echo "[temporal init] setting up the temporal schema"
run_cmd "temporal-sql-tool --db temporal setup-schema -v 0.0"

echo "[temporal init] updating the temporal schema"
run_cmd "temporal-sql-tool --db temporal update-schema -d ./schema/postgresql/v12/temporal/versioned/"

echo "[temporal_visibility init] creating the temporal_visibility database"
run_cmd "temporal-sql-tool --db temporal_visibility create"

echo "[temporal_visibility init] setting up the temporal_visibility schema"
run_cmd "temporal-sql-tool --db temporal_visibility setup-schema -v 0.0"

echo "[temporal_visibility init] updating the temporal_visibility schema"
run_cmd "temporal-sql-tool --db temporal_visibility update-schema -d ./schema/postgresql/v12/temporal/versioned/"
