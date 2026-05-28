#!/usr/bin/env bash
#
# Cancel every runner_jobs row of a shutdown-type that is still active
# (queued, available, or in-progress) by setting status to "cancelled".
#
# Targeted job types:
#   - shut-down
#   - mng-shut-down
#   - mng-vm-shut-down

set -e
set -o pipefail
set -u

db_name="${DB_NAME:-ctl_api}"
db_port="${DB_PORT:-5432}"
db_addr="$DB_ADDR"
secret_arn="$SECRET_ARN"
region="$REGION"

echo "[cancel-shutdown-runner-jobs] kubectl auth whoami"
kubectl auth whoami -o json | jq -c

echo "[cancel-shutdown-runner-jobs] loading db credentials"
secret=$(aws --region "$region" secretsmanager get-secret-value --secret-id="$secret_arn")
admin_username=$(echo "$secret" | jq -r '.SecretString' | jq -r '.username')
admin_password=$(echo "$secret" | jq -r '.SecretString' | jq -r '.password')

echo "[cancel-shutdown-runner-jobs] scale up ctl-api-init"
kubectl scale -n ctl-api --replicas=1 deployment/ctl-api-init
kubectl wait deployment -n ctl-api ctl-api-init --for condition=Available=True --timeout=300s

pod=$(kubectl -n ctl-api get pods --selector app=ctl-api-init -o json | jq -r '.items[0].metadata.name')
echo "[cancel-shutdown-runner-jobs] using pod: $pod"

sql="
UPDATE runner_jobs
SET status = 'cancelled',
    status_description = 'cancelled by temporal_hard_reset SoP'
WHERE type IN ('shut-down', 'mng-shut-down', 'mng-vm-shut-down')
  AND status IN ('queued', 'available', 'in-progress')
RETURNING id, type, status_description;
"

echo "[cancel-shutdown-runner-jobs] running update"
kubectl --namespace=ctl-api exec -i "$pod" -- \
  env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$admin_username" "PGPASSWORD=$admin_password" \
  psql --no-psqlrc -d "$db_name" -c "$sql"

echo "[cancel-shutdown-runner-jobs] scale down ctl-api-init"
kubectl scale -n ctl-api --current-replicas=1 --replicas=0 deployment/ctl-api-init

echo "[cancel-shutdown-runner-jobs] done"
