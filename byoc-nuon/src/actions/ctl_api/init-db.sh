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
kubectl auth whoami -o json


echo "[ctl_api init] scale up the deployment"
kubectl scale -n ctl-api --replicas=1 deployment/ctl-api-init
kubectl wait deployment -n ctl-api ctl-api-init --for condition=Available=True --timeout=90s

echo "[ctl_api init] get a pod from the deployment"
pod=`kubectl -n ctl-api get pods --selector app=ctl-api-init -o json | jq -r '.items[0].metadata.name'`

echo "[ctl_api init] reading db access secrets from AWS"
secret=`aws --region $region secretsmanager get-secret-value --secret-id=$secret_arn`
admin_username=`echo $secret | jq -r '.SecretString' | jq -r '.username'`
admin_password=`echo $secret | jq -r '.SecretString' | jq -r '.password'`
admin_db="nuonadmin"

echo "[ctl_api init] preparing to initialize"
function run_cmd() {
  echo " > cmd: $@"
  kubectl \
    --namespace=ctl-api \
    exec  -i \
    $pod -- \
    env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$admin_username" "PGPASSWORD=$admin_password" \
    psql --no-psqlrc -d "$1" -f "$2"
}

# these can fail on subsequent runs
echo "[ctl_api init] enable hstore"
run_cmd "$admin_db" "/var/init-config/create_hstore.sql"
sleep 5

echo "[ctl_api init] ensuring user"
run_cmd "$admin_db" "/var/init-config/create_user.sql"
sleep 5

echo "[ctl_api init] grant iam to user"
run_cmd "$admin_db" "/var/init-config/grant_user_iam.sql"
sleep 5

echo "[ctl_api init] alter user to allow create db"
run_cmd "$admin_db" "/var/init-config/alter_user_createdb.sql"
sleep 5

echo "[ctl_api init] create db"
run_cmd "$admin_db" "/var/init-config/create_db.sql"
sleep 5

echo "[ctl_api init] grant all on db to ctl_api"
run_cmd "$admin_db" "/var/init-config/grant_db.sql"

echo "[ctl_api init] grant all on db to ctl_api"
run_cmd "$admin_db" "/var/init-config/create_hstore.sql"

echo "[ctl_api init] scale down the deployment"
kubectl scale -n ctl-api --current-replicas=1 --replicas=0 deployment/ctl-api-init
