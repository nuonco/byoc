#!/usr/bin/env bash

set -e
set -o pipefail
set -u

db_name="$DB_NAME" # admin db
db_user="$DB_USER"
db_addr="$DB_ADDR"
db_port="$DB_PORT"
region="$REGION"
secret_arn="$SECRET_ARN"

# TODO: make the cluster's default/admin db and the ctl-api db distinct

echo "[ctl_api init] kubectl auth whoami"
echo "pwd: "`pwd`
kubectl auth whoami -o json | jq -c


echo "[ctl_api init] scale up the deployment"
kubectl scale -n ctl-api --replicas=1 deployment/ctl-api-init
kubectl wait deployment -n ctl-api ctl-api-init --for condition=Available=True --timeout=300s

echo "[ctl_api init] get a pod from the deployment"
pod=`kubectl -n ctl-api get pods --selector app=ctl-api-init -o json | jq -r '.items[0].metadata.name'`

echo "[ctl_api init] reading db access secrets from AWS"
secret=`aws --region $region secretsmanager get-secret-value --secret-id=$secret_arn`
admin_username=`echo $secret | jq -r '.SecretString' | jq -r '.username'`
admin_password=`echo $secret | jq -r '.SecretString' | jq -r '.password'`

echo "[ctl_api init] sanity check"
echo "these two should match"
echo "db_user=$db_user"
echo "username=$admin_username"

function run_cmd() {
  echo " > cmd: $@"
  kubectl \
    --namespace=ctl-api \
    exec  -i \
    $pod -- \
    env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$admin_username" "PGPASSWORD=$admin_password" \
    psql --no-psqlrc -d "ctl_api" -c "$1"
}

#
# dump views
#
kubectl \
  --namespace=ctl-api \
  exec  -i \
  $pod -- \
  env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$admin_username" "PGPASSWORD=$admin_password" \
  psql --no-psqlrc -t -d "ctl_api" -c "select viewname from pg_views where schemaname = 'public'" > /tmp/views

for view in `cat /tmp/views`; do
  run_cmd "ALTER VIEW $view OWNER TO ctl_api;"
done

#
# dump tables
#
kubectl \
  --namespace=ctl-api \
  exec  -i \
  $pod -- \
  env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$admin_username" "PGPASSWORD=$admin_password" \
  psql --no-psqlrc -t -d "ctl_api" -c "select tablename from pg_tables where schemaname = 'public'" > /tmp/tables

for table in `cat /tmp/tables`; do
  run_cmd "ALTER TABLE $table OWNER TO ctl_api;"
done


run_cmd "\d"

# NOTE: only necessary to recover
echo "grant ctl_api access"
run_cmd "SELECT d.datname as \"Name\", pg_catalog.pg_get_userbyid(d.datdba) as \"Owner\" FROM pg_catalog.pg_database d WHERE d.datname = 'ctl_api' ORDER BY 1;"
run_cmd "GRANT ALL PRIVILEGES ON DATABASE ctl_api to ctl_api;"
run_cmd "GRANT CONNECT ON DATABASE ctl_api TO ctl_api;"
run_cmd "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ctl_api;"
run_cmd "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ctl_api;"
run_cmd "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ctl_api;"
run_cmd "GRANT USAGE ON SCHEMA public TO ctl_api;"
run_cmd "ALTER DATABASE ctl_api OWNER TO ctl_api;"

# one time deal


# let's see it again



echo "[must be owner of tablectl_api init] count empty emails"
run_cmd "select count(id) from accounts where email = '';"

echo "[ctl_api init] count account email domains"
run_cmd "select count(split_part(email, '@', 2)), split_part(email, '@', 2) AS domain from accounts where account_type = 'auth0' group by split_part(email, '@', 2);"

echo "[ctl_api init] count app configs"
run_cmd "select count(id) from app_configs;"

echo "[ctl_api init] count orgs"
run_cmd "select count(id) from orgs;"

echo "[ctl_api init] count installs"
run_cmd "select org_id, id from installs order by org_id;"
