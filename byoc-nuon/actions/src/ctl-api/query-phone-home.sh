#!/usr/bin/env bash
#
# Query phone-home state for an install and emit the results to the action's
# outputs file ($NUON_ACTIONS_OUTPUT_FILEPATH) so they appear in the UI's
# Outputs tab.
#
# The entire JSON envelope is constructed inside Postgres so we don't have to
# combine multiple psql outputs in shell (which is fragile with --argjson).

set -e
set -o pipefail
set -u

db_name="$DB_NAME"
db_user="$DB_USER"
db_addr="$DB_ADDR"
db_port="$DB_PORT"
region="$REGION"
secret_arn="$SECRET_ARN"
install_id="$INSTALL_ID"

echo "[query phone-home] kubectl auth whoami"
kubectl auth whoami -o json | jq -c

echo "[query phone-home] scale up ctl-api-init"
kubectl scale -n ctl-api --replicas=1 deployment/ctl-api-init
kubectl wait deployment -n ctl-api ctl-api-init --for condition=Available=True --timeout=300s

pod=$(kubectl -n ctl-api get pods --selector app=ctl-api-init -o json | jq -r '.items[0].metadata.name')
echo "[query phone-home] using pod: $pod"

echo "[query phone-home] loading db credentials"
secret=$(aws --region "$region" secretsmanager get-secret-value --secret-id="$secret_arn")
admin_username=$(echo "$secret" | jq -r '.SecretString' | jq -r '.username')
admin_password=$(echo "$secret" | jq -r '.SecretString' | jq -r '.password')

sql="
SET default_transaction_read_only = on;
SELECT json_build_object(
  'install_id', '$install_id',
  'stack_versions', (
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
    FROM (
      SELECT id, install_id, install_stack_id, phone_home_id, phone_home_url,
             status, created_at, updated_at
      FROM install_stack_versions
      WHERE install_id = '$install_id'
      ORDER BY created_at DESC
    ) t
  ),
  'runs', (
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
    FROM (
      SELECT r.id AS run_id,
             r.install_stack_version_id,
             r.created_at,
             hstore_to_json(r.data) AS data
      FROM install_stack_version_runs r
      JOIN install_stack_versions v ON v.id = r.install_stack_version_id
      WHERE v.install_id = '$install_id'
      ORDER BY r.created_at DESC
    ) t
  )
)::text;
"

echo "[query phone-home] running query"
output=$(kubectl --namespace=ctl-api exec -i "$pod" -- \
  env "PGHOST=$db_addr" "PGPORT=$db_port" "PGUSER=$admin_username" "PGPASSWORD=$admin_password" \
  psql --no-psqlrc -d "$db_name" -A -t -c "$sql" | tr -d '\r' | grep -v '^$' | tail -n 1)

echo "[query phone-home] scale down ctl-api-init"
kubectl scale -n ctl-api --current-replicas=1 --replicas=0 deployment/ctl-api-init

if [[ -z "$output" ]]; then
  echo "[query phone-home] ERROR: empty result from db" >&2
  exit 1
fi

# Validate JSON before writing so a malformed result fails the step loudly
# rather than silently corrupting outputs.
echo "$output" | jq . > /dev/null

echo "[query phone-home] writing outputs"
echo "$output" > "$NUON_ACTIONS_OUTPUT_FILEPATH"

echo "[query phone-home] preview:"
echo "$output" | jq .
