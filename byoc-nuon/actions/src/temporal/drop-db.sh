#!/usr/bin/env bash

# drop the temporal database using temporal-sql-tools

set -e
set -u pipefail
set -o

echo "[temporal] kubectl auth whoami"
echo "pwd: $(pwd)"
kubectl auth whoami -o json | jq -c

echo "[temporal] scale up the deployment"
kubectl scale -n temporal --replicas=1 deployment/temporal-init
kubectl wait deployment -n temporal temporal-init --for condition=Available=True --timeout=300s

echo "[temporal] get a pod from the deployment"
pod=$(kubectl -n temporal get pods --selector app=temporal-init -o json | jq -r '.items[0].metadata.name')

echo "[temporal] preparing to drop"
function run_cmd() {
  echo " > cmd: $@"
  kubectl --namespace=temporal exec -i $pod -- sh -c "$1"
}

echo "[temporal] sql tools - temporal db"
run_cmd "temporal-sql-tool --database visibility drop-database --force"
run_cmd "temporal-sql-tool --database temporal drop-database --force"
