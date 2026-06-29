#!/usr/bin/env bash

set -e
set -o pipefail
set -u

db_name="$DB_NAME" # admin db
db_user="$DB_USER"
db_addr="$DB_ADDR"
db_port="$DB_PORT"

# Wait for the GKE API server to be reachable before doing anything else. This
# is a pre-deploy-component hook, so it's often the first kubectl call against a
# freshly-provisioned cluster — the control-plane endpoint and its networking
# can lag a few seconds behind the cluster reporting ready, so the first kubectl
# call may i/o-timeout even though the cluster is healthy. Poll a lightweight
# endpoint until it answers instead.
wait_for_apiserver() {
  attempts=24
  i=1
  while true; do
    if kubectl get --raw='/healthz' --request-timeout=10s >/dev/null 2>&1; then
      echo "[ctl_api init] API server reachable (attempt ${i})."
      return 0
    fi
    if [ "$i" -ge "$attempts" ]; then
      echo "[ctl_api init] ERROR: API server not reachable after ${attempts} attempts (~4m)." >&2
      kubectl get --raw='/healthz' --request-timeout=10s || true # surface the real error
      return 1
    fi
    echo "[ctl_api init] API server not reachable yet (attempt ${i}/${attempts}), retrying in 10s..."
    i=$((i + 1))
    sleep 10
  done
}

echo "[ctl_api init] waiting for the API server"
wait_for_apiserver

# TODO: make the cluster's default/admin db and the ctl-api db distinct

echo "[ctl_api init] kubectl auth whoami"
echo "pwd: "`pwd`
kubectl auth whoami -o json | jq -c

echo "[ctl_api init] scale up the deployment"
kubectl scale -n ctl-api --replicas=1 deployment/ctl-api-init
kubectl wait deployment -n ctl-api ctl-api-init --for condition=Available=True --timeout=300s

echo "[ctl_api init] get a pod from the deployment"
pod=`kubectl -n ctl-api get pods --selector app=ctl-api-init -o json | jq -r '.items[0].metadata.name'`

echo "[ctl_api init] reading db access secrets from k8s"
admin_username=$(kubectl get -n ctl-api secret nuon-db -o jsonpath='{.data.username}' | base64 -d)
admin_password=$(kubectl get -n ctl-api secret nuon-db -o jsonpath='{.data.password}' | base64 -d)

echo "[ctl_api init] sanity check"
echo "these two should match"
echo "db_user=$db_user"
echo "username=$admin_username"

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
run_cmd "$db_name" "/var/init-config/create_hstore.sql"
sleep 5

echo "[ctl_api init] ensuring user"
run_cmd "$db_name" "/var/init-config/create_user.sql"
sleep 5

echo "[ctl_api init] alter user to allow create db"
run_cmd "$db_name" "/var/init-config/alter_user_createdb.sql"
sleep 5

echo "[ctl_api init] create db"
run_cmd "$db_name" "/var/init-config/create_db.sql"
sleep 5

echo "[ctl_api init] grant all on db to ctl_api"
run_cmd "$db_name" "/var/init-config/grant_db.sql"

echo "[ctl_api init] grant all on public"
run_cmd "ctl_api" "/var/init-config/grant_public.sql"

echo "[ctl_api init] hstore"
run_cmd "ctl_api" "/var/init-config/create_hstore.sql"

echo "[ctl_api init] validate"
kubectl \
  --namespace=ctl-api \
  exec  -i \
  $pod -- \
  env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$admin_username" "PGPASSWORD=$admin_password" \
  psql --no-psqlrc -d "ctl_api" -c "\du"

echo "[ctl_api init] scale down the deployment"
kubectl scale -n ctl-api --current-replicas=1 --replicas=0 deployment/ctl-api-init
