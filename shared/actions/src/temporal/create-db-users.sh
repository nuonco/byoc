#!/usr/bin/env bash
set -euo pipefail

echo "[temporal init] scale up the deployment"
kubectl scale -n temporal --replicas=1 deployment/temporal-psql
kubectl wait deployment -n temporal temporal-psql --for condition=Available=True --timeout=300s

pod=$(kubectl -n temporal get pods --selector app=temporal-psql -o json | jq -r '.items[0].metadata.name')

echo "[temporal init] ensure db users - temporal"
kubectl --namespace=temporal exec -i $pod -- \
  sh -c 'bash /var/init-config/create_db_users.sh temporal temporal $TEMPORAL_DB_PW'

echo "[temporal init] ensure db users - temporal_visibility"
kubectl --namespace=temporal exec -i $pod -- \
  sh -c 'bash /var/init-config/create_db_users.sh temporal_visibility temporal_visibility $TEMPORAL_VISIBILITY_DB_PW'

echo "[temporal init] scale down the deployment"
kubectl scale -n temporal --current-replicas=1 --replicas=0 deployment/temporal-psql
