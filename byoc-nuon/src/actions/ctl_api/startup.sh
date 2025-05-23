#!/usr/bin/env bash

set -e
set -o pipefail
set -u

db_addr="$DB_ADDR"
db_port="$DB_PORT"
region="$REGION"
secret_arn="$SECRET_ARN"

# internal
deployment_name="ctl-api-startup"

echo "[ctl_api startup] kubectl auth whoami"
kubectl auth whoami -o json | jq -c

echo "[ctl_api startup] scale up the deployment"
# NOTE(fd): this is only stricktly necessary when we run this action manually. during the normal
# course of a deployment, this action runs right after ctl-api which means this deployment will
# already be scaled up.
kubectl scale -n ctl-api --replicas=1 "deployment/$deployment_name"
kubectl wait deployment -n ctl-api $deployment_name --for condition=Available=True --timeout=90s

echo "[ctl_api startup] get a pod from the deployment"
pod=`kubectl -n ctl-api get pods --selector app.nuon.co/name="$deployment_name" -o json | jq -r '.items[0].metadata.name'`

echo "[ctl_api startup] preparing to initialize"
kubectl --namespace=ctl-api exec  -i $pod -- /bin/service startup

echo "[ctl_api startup] scale down the deployment"
kubectl scale -n ctl-api --current-replicas=1 --replicas=0 "deployment/$deployment_name"
