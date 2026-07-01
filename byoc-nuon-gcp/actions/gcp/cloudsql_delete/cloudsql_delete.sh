#!/usr/bin/env bash

set -e
set -o pipefail
set -u

# Deletes a single Cloud SQL instance via the gcloud API, taking a FINAL BACKUP
# as part of the delete. This is the explicit destruction step of a Cloud SQL
# teardown: it is intentionally decoupled from the Terraform deploy/teardown job
# so deleting the database is always a deliberate, audited action rather than a
# side effect of a plan.
#
# GCP note: deleting a Cloud SQL instance also deletes its automated and
# on-demand backups. A FINAL BACKUP is the one artifact that survives deletion
# (the GCP equivalent of an AWS final DB snapshot), so we always request one.
#
# Required env:
#   DB_INSTANCE_NAME  the Cloud SQL instance name (cloudsql_*.outputs.db_instance_name)
#   PROJECT_ID        the GCP project id
# Optional env:
#   DB_LABEL                     human-friendly label used in log output (defaults to "database")
#   FINAL_BACKUP_RETENTION_DAYS  retention for the final backup, 1-365 (defaults to 30)

db_instance_name="$DB_INSTANCE_NAME"
project_id="$PROJECT_ID"
db_label="${DB_LABEL:-database}"
retention_days="${FINAL_BACKUP_RETENTION_DAYS:-30}"

echo "==================================================================="
echo " Cloud SQL delete: ${db_label}  (instance: ${db_instance_name})"
echo "==================================================================="

# ── does the instance still exist? ───────────────────────────────────────────
if ! inst_state=$(gcloud sql instances describe "$db_instance_name" \
  --project "$project_id" --format='value(state)' 2>/dev/null); then
  echo "Instance ${db_instance_name} not found — already deleted. Nothing to do."
  exit 0
fi
echo "Instance state: ${inst_state}"

# ── refuse to delete a deletion-protected instance ───────────────────────────
# We mirror the AWS behaviour: deletion protection must be cleared via the normal
# config path (the component's deletion_protection var), not bypassed here. This
# reads the API-level guard (settings.deletionProtectionEnabled).
protected=$(gcloud sql instances describe "$db_instance_name" \
  --project "$project_id" \
  --format='value(settings.deletionProtectionEnabled)' 2>/dev/null || true)

if [ "$protected" = "True" ] || [ "$protected" = "true" ]; then
  echo "ERROR: ${db_instance_name} has deletion protection enabled." >&2
  echo "Set deletion_protection=false on the component and redeploy before running this action." >&2
  exit 1
fi

# Final backup description must be short; stamp it so re-runs are distinguishable.
stamp=$(date -u +%Y%m%d-%H%M%S)
description="byoc-nuon teardown ${db_instance_name} ${stamp}"

echo ""
echo "Deleting instance ${db_instance_name} with a final backup (retention ${retention_days}d)..."
gcloud sql instances delete "$db_instance_name" \
  --project "$project_id" \
  --enable-final-backup \
  --final-backup-retention-days "$retention_days" \
  --final-backup-description "$description" \
  --quiet

echo ""
echo "Instance ${db_instance_name} deleted. Final backup retained ${retention_days} day(s)."
echo "  description: ${description}"
echo "NOTE: the Terraform component still references this instance in its state."
echo "      Detaching it from state is a separate step (the state_rm step of this hook)."

# Surface the final backup description to downstream steps / the action output.
if [ -n "${NUON_ACTIONS_OUTPUT_FILEPATH:-}" ]; then
  echo "CLOUDSQL_FINAL_BACKUP_DESCRIPTION=${description}" >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
fi
