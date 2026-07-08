#!/usr/bin/env bash

set -e
set -o pipefail
set -u

db_user="$DB_USER"
db_pass="$DB_PASS"
db_addr="$DB_ADDR"
db_port="$DB_PORT"
db_name="$DB_NAME"
query="$QUERY"

echo "[temporal query] kubectl auth whoami"
echo "pwd: "`pwd`
kubectl auth whoami -o json | jq -c


echo "[temporal query] scale up the deployment"
kubectl scale -n temporal --replicas=1 deployment/temporal-psql
kubectl wait deployment -n temporal temporal-psql --for condition=Available=True --timeout=300s

echo "[temporal query] get a pod from the deployment"
pod=`kubectl -n temporal get pods --selector app=temporal-psql -o json | jq -r '.items[0].metadata.name'`

echo "[temporal query] preparing to query"
function execute_query() {
  echo " > query: $1"
  kubectl \
    --namespace=temporal \
    exec  -i \
    $pod -- \
    env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$db_user" "PGPASSWORD=$db_pass" "PGSSLMODE=require" \
    psql --no-psqlrc -d "$db_name" -c "$1"
}
# sleep so logs have time to flush?
sleep 1

execute_query "$query"

echo "[temporal query] scale down the deployment"
kubectl scale -n temporal --current-replicas=1 --replicas=0 deployment/temporal-psql
