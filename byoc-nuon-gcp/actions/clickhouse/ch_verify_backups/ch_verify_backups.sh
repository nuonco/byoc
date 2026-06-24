#!/usr/bin/env bash

set -e
set -o pipefail
set -u

# Verifies the ClickHouse GCS backup pipeline:
#   1. the HMAC credential secret exists
#   2. the backup CronJob(s) exist
#   3. a manually-triggered backup run completes (logs should show BACKUP_CREATED)
#   4. backup objects are present in the GCS bucket
#
# Required env:
#   BUCKET_NAME   the ClickHouse backup bucket (gcs_buckets.outputs.clickhouse_bucket.name)
# Optional env:
#   BACKUP_TABLE  the table to verify (default "ctl_api.otel_log_records")
#
# Emits (to $NUON_ACTIONS_OUTPUT_FILEPATH): indicator, backup_job, table, cronjob,
#   objects_found, updated_at

NS=clickhouse
BUCKET="$BUCKET_NAME"
TABLE="${BACKUP_TABLE:-ctl_api.otel_log_records}"
# cron name mirrors backups.tf: replace "_"->"-" then strip leading "ctl-api."
CRON="ch-gcs-backup-$(echo "$TABLE" | sed 's/_/-/g; s/ctl-api\.//')"

echo "### HMAC credential secret"
secret_ok="true"
kubectl -n "$NS" get secret clickhouse-backup-hmac || secret_ok="false"

echo
echo "### Backup CronJobs"
kubectl -n "$NS" get cronjob

echo
echo "### Triggering a backup run from cronjob/$CRON"
job="backup-verify-$(date +%s)"
kubectl -n "$NS" create job "$job" --from=cronjob/"$CRON"

set +e
kubectl -n "$NS" wait --for=condition=complete "job/$job" --timeout=300s
rc=$?
set -e

echo
echo "### Job logs (expect BACKUP_CREATED)"
kubectl -n "$NS" logs -l "job-name=$job" --tail=40 || true
kubectl -n "$NS" delete job "$job" || true

echo
echo "### Objects in gs://$BUCKET/backups/$TABLE/"
objects_found=$(gcloud storage ls "gs://$BUCKET/backups/$TABLE/" 2>/dev/null | grep -c . || true)
gcloud storage ls "gs://$BUCKET/backups/$TABLE/" || true

if [ "$rc" = "0" ]; then
  backup_job="completed"
else
  backup_job="did-not-complete"
fi
echo "backup job: $backup_job  objects_found: $objects_found"

# 🟢 when the secret exists, the run completed, and objects are present
indicator="🔴"
if [ "$secret_ok" = "true" ] && [ "$rc" = "0" ] && [ "$objects_found" -gt 0 ]; then
  indicator="🟢"
fi

jq -n -c \
  --arg ind "$indicator" \
  --arg s "$backup_job" \
  --arg t "$TABLE" \
  --arg c "$CRON" \
  --argjson of "$objects_found" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{indicator: $ind, backup_job: $s, table: $t, cronjob: $c, objects_found: $of, updated_at: $ts}' \
  >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
