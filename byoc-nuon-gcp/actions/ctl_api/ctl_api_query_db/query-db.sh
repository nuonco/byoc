#!/usr/bin/env bash

set -e
set -o pipefail
set -u

db_name="$DB_NAME"
db_user="$DB_USER"
db_addr="$DB_ADDR"
db_port="$DB_PORT"
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

# Query as the ctl-api IAM role (the table owner) via Cloud SQL IAM auth. The
# nuon-db admin user is NOT the owner and gets "permission denied". Impersonate
# the ctl-api SA on the runner (ctl_api_wi grants the runner token-creator on it)
# to mint a sqlservice.login-scoped token, used as the DB password over SSL.
: "${CTL_API_SA_EMAIL:?CTL_API_SA_EMAIL is required (ctl_api_wi.service_account_email)}"
echo "[ctl_api query] minting a Cloud SQL login token as ${CTL_API_SA_EMAIL}"
db_token=$(gcloud auth print-access-token \
  --impersonate-service-account="$CTL_API_SA_EMAIL" \
  --scopes=https://www.googleapis.com/auth/sqlservice.login)
if [[ -z "$db_token" ]]; then
  echo "[ctl_api query] ERROR: failed to mint a login token as $CTL_API_SA_EMAIL." >&2
  exit 1
fi

echo "[ctl_api query] preparing to initialize"
function execute_query() {
  echo " > query: $1"
  kubectl \
    --namespace=ctl-api \
    exec  -i \
    $pod -- \
    env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$db_user" "PGPASSWORD=$db_token" "PGSSLMODE=require" \
    psql --no-psqlrc -d "ctl_api" -c "SET default_transaction_read_only = on; $1"
}
# sleep so logs have time to flush?
sleep 1

execute_query "$query"

echo "[ctl_api query] scale down the deployment"
kubectl scale -n ctl-api --current-replicas=1 --replicas=0 deployment/ctl-api-init
