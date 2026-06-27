#!/usr/bin/env bash

set -euo pipefail

echo "[db-access query] kubectl auth whoami"
kubectl auth whoami -o json | jq -c

echo "[db-access query] scale up db-tools deployment"
kubectl scale -n db-tools --replicas=1 deployment/db-tools
kubectl wait deployment -n db-tools db-tools --for condition=Available=True --timeout=300s

echo "[db-access query] get pod"
pod=$(kubectl -n db-tools get pods --selector app=db-tools -o json | jq -r '.items[0].metadata.name')

echo "[db-access query] generating IAM auth token"
token=$(aws rds generate-db-auth-token \
  --hostname "$DB_ADDR" \
  --port "$DB_PORT" \
  --region "$REGION" \
  --username "$DB_USER")

echo "[db-access query] running query: $QUERY"
kubectl \
  --namespace=db-tools \
  exec -i \
  "$pod" -- \
  env "PGHOST=$DB_ADDR" "PGPORT=$DB_PORT" "PGUSER=$DB_USER" "PGPASSWORD=$token" "PGSSLMODE=require" \
  psql --no-psqlrc -d "$DB_NAME" -c "SET default_transaction_read_only = on; $QUERY"

echo "[db-access query] scale down db-tools deployment"
kubectl scale -n db-tools --current-replicas=1 --replicas=0 deployment/db-tools
