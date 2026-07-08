#!/usr/bin/env bash
#
# Cancel every in-flight queue_signal in the ctl_api DB. Sets status to
# "cancelled" for any signal not already in a terminal state. Run while the
# Temporal server and ctl-api workers are scaled down so nothing re-enqueues
# mid-update.
#
# This is a WRITE action (unlike ctl_api_query_db, which forces a read-only
# transaction).

set -e
set -o pipefail
set -u

db_addr="$DB_ADDR"
db_port="$DB_PORT"
db_user="$DB_USER"
region="$REGION"
secret_arn="$SECRET_ARN"
cancelled_by="${CANCELLED_BY:-clear-org-queues}"

QUERY="UPDATE queue_signals
   SET status = jsonb_build_object(
           'created_at_ts',            extract(epoch from now())::bigint,
           'status',                   'cancelled',
           'status_human_description', 'cancelled by ${cancelled_by}',
           'metadata',                 jsonb_build_object('cancelled_by', '${cancelled_by}')
       ),
       updated_at = now()
 WHERE deleted_at = 0
   AND coalesce(status->>'status', '') NOT IN ('success', 'cancelled', 'discarded', 'error');"

echo "[clear-org-queues] kubectl auth whoami"
kubectl auth whoami -o json | jq -c

echo "[clear-org-queues] scale up the deployment"
kubectl scale -n ctl-api --replicas=1 deployment/ctl-api-init
kubectl wait deployment -n ctl-api ctl-api-init --for condition=Available=True --timeout=300s

echo "[clear-org-queues] get a pod from the deployment"
pod=$(kubectl -n ctl-api get pods --selector app=ctl-api-init -o json | jq -r '.items[0].metadata.name')

echo "[clear-org-queues] reading db access secrets from AWS"
secret=$(aws --region "$region" secretsmanager get-secret-value --secret-id="$secret_arn")
admin_username=$(echo "$secret" | jq -r '.SecretString' | jq -r '.username')
admin_password=$(echo "$secret" | jq -r '.SecretString' | jq -r '.password')

echo "[clear-org-queues] sanity check (these two should match)"
echo "db_user=$db_user"
echo "username=$admin_username"

echo "[clear-org-queues] executing update"
echo " > query: $QUERY"
# sleep so logs have time to flush
sleep 1

kubectl \
  --namespace=ctl-api \
  exec -i \
  "$pod" -- \
  env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$admin_username" "PGPASSWORD=$admin_password" \
  psql --no-psqlrc -d "ctl_api" -c "$QUERY"

echo "[clear-org-queues] scale down the deployment"
kubectl scale -n ctl-api --current-replicas=1 --replicas=0 deployment/ctl-api-init
