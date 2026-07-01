#!/usr/bin/env bash
#
# Cancel every install_workflows row whose composite status is "queued" by
# updating status->'status' to "cancelled" and appending the prior status to
# the history array.
#
# Env vars (with defaults from the action toml):
#   DB_NAME     defaults to "ctl_api"
#   DB_PORT     defaults to "5432"
#   DB_ADDR     Cloud SQL endpoint (required)

set -e
set -o pipefail
set -u

db_name="${DB_NAME:-ctl_api}"
db_port="${DB_PORT:-5432}"
db_addr="$DB_ADDR"

echo "[cancel-queued-workflows] kubectl auth whoami"
kubectl auth whoami -o json | jq -c

# Update as the ctl-api IAM role (the table owner) via Cloud SQL IAM auth. The
# nuon-db admin user is NOT the owner and gets "permission denied". Impersonate
# the ctl-api SA on the runner (ctl_api_wi grants the runner token-creator on it)
# to mint a sqlservice.login-scoped token, used as the DB password over SSL.
: "${DB_USER:?DB_USER is required (ctl_api_wi.db_user, the IAM database user)}"
: "${CTL_API_SA_EMAIL:?CTL_API_SA_EMAIL is required (ctl_api_wi.service_account_email)}"
echo "[cancel-queued-workflows] minting a Cloud SQL login token as ${CTL_API_SA_EMAIL}"
db_token=$(gcloud auth print-access-token \
  --impersonate-service-account="$CTL_API_SA_EMAIL" \
  --scopes=https://www.googleapis.com/auth/sqlservice.login)
if [[ -z "$db_token" ]]; then
  echo "[cancel-queued-workflows] ERROR: failed to mint a login token as $CTL_API_SA_EMAIL." >&2
  exit 1
fi

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
  env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$DB_USER" "PGPASSWORD=$db_token" "PGSSLMODE=require" \
  psql --no-psqlrc -d "$db_name" -c "$sql"

echo "[cancel-queued-workflows] scale down ctl-api-init"
kubectl scale -n ctl-api --current-replicas=1 --replicas=0 deployment/ctl-api-init

echo "[cancel-queued-workflows] done"
