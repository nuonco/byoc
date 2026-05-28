#!/usr/bin/env bash
#
# Cancel every install_workflows row whose composite status is "queued" by
# updating status->'status' to "cancelled" and appending the prior status to
# the history array.
#
# Env vars (with defaults from the action toml):
#   DB_NAME     defaults to "ctl_api"
#   DB_PORT     defaults to "5432"
#   DB_ADDR     RDS endpoint (required)
#   SECRET_ARN  master-user secret ARN (required)
#   REGION      AWS region (required)

set -e
set -o pipefail
set -u

db_name="${DB_NAME:-ctl_api}"
db_port="${DB_PORT:-5432}"
db_addr="$DB_ADDR"
secret_arn="$SECRET_ARN"
region="$REGION"

echo "[cancel-queued-workflows] kubectl auth whoami"
kubectl auth whoami -o json | jq -c

echo "[cancel-queued-workflows] loading db credentials"
secret=$(aws --region "$region" secretsmanager get-secret-value --secret-id="$secret_arn")
admin_username=$(echo "$secret" | jq -r '.SecretString' | jq -r '.username')
admin_password=$(echo "$secret" | jq -r '.SecretString' | jq -r '.password')

echo "[cancel-queued-workflows] scale up ctl-api-init"
kubectl scale -n ctl-api --replicas=1 deployment/ctl-api-init
kubectl wait deployment -n ctl-api ctl-api-init --for condition=Available=True --timeout=300s

pod=$(kubectl -n ctl-api get pods --selector app=ctl-api-init -o json | jq -r '.items[0].metadata.name')
echo "[cancel-queued-workflows] using pod: $pod"

sql="
WITH targets AS (
  SELECT id, status FROM install_workflows
  WHERE deleted_at = 0
    AND status->>'status' = 'queued'
)
UPDATE install_workflows w
SET status = jsonb_set(
  jsonb_set(
    jsonb_set(w.status,
      '{status}', '\"cancelled\"'::jsonb),
    '{status_human_description}', '\"cancelled by temporal_hard_reset SoP\"'::jsonb),
  '{history}',
    COALESCE(w.status->'history', '[]'::jsonb) || jsonb_build_array(t.status - 'history')
)
FROM targets t
WHERE w.id = t.id
RETURNING w.id;
"

echo "[cancel-queued-workflows] running update"
kubectl --namespace=ctl-api exec -i "$pod" -- \
  env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$admin_username" "PGPASSWORD=$admin_password" \
  psql --no-psqlrc -d "$db_name" -c "$sql"

echo "[cancel-queued-workflows] scale down ctl-api-init"
kubectl scale -n ctl-api --current-replicas=1 --replicas=0 deployment/ctl-api-init

echo "[cancel-queued-workflows] done"
