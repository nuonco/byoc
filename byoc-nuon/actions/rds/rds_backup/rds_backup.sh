#!/usr/bin/env bash

set -e
set -o pipefail
set -u

# Takes a deliberate, identifiable manual snapshot of a single RDS instance and
# waits for it to complete. Intended as the first, explicit step of an RDS
# teardown runbook: capture a recoverable backup BEFORE the instance is deleted.
#
# Required env:
#   DB_RESOURCE_ID  the stable DbiResourceId of the instance
#                   (rds_cluster_*.outputs.db_instance_resource_id)
# Optional env:
#   DB_LABEL        human-friendly label used in log output (defaults to "database")
#   SNAPSHOT_SUFFIX suffix appended to the snapshot id (defaults to "teardown")
#
# Emits the resulting snapshot id to the action output file (if available) under
# the key RDS_BACKUP_SNAPSHOT_ID so later steps can reference it.

export AWS_PAGER=""

db_resource_id="$DB_RESOURCE_ID"
db_label="${DB_LABEL:-database}"
snapshot_suffix="${SNAPSHOT_SUFFIX:-teardown}"

echo "==================================================================="
echo " RDS backup: ${db_label}  (resource id: ${db_resource_id})"
echo "==================================================================="

# Resolve the human instance identifier from the stable resource id, so this
# keeps working across instance renames / replacements.
db_instance_id=$(aws rds describe-db-instances \
  --query "DBInstances[?DbiResourceId=='${db_resource_id}'].DBInstanceIdentifier" \
  --output text)

if [ -z "$db_instance_id" ] || [ "$db_instance_id" = "None" ]; then
  echo "ERROR: no RDS instance found with DbiResourceId='${db_resource_id}'." >&2
  echo "The instance may already be deleted. Aborting backup." >&2
  exit 1
fi

# Snapshot ids: start with a letter, alphanumeric + single hyphens, no trailing
# hyphen. The instance id already satisfies this; append a stamped suffix.
stamp=$(date -u +%Y%m%d-%H%M%S)
snapshot_id="${db_instance_id}-${snapshot_suffix}-${stamp}"

echo "Instance:  ${db_instance_id}"
echo "Snapshot:  ${snapshot_id}"
echo ""
echo "Creating manual snapshot..."
aws rds create-db-snapshot \
  --db-instance-identifier "$db_instance_id" \
  --db-snapshot-identifier "$snapshot_id" >/dev/null

echo "Waiting for snapshot to complete (this can take several minutes)..."
aws rds wait db-snapshot-completed \
  --db-snapshot-identifier "$snapshot_id"

# Confirm it really landed in 'available'.
status=$(aws rds describe-db-snapshots \
  --db-snapshot-identifier "$snapshot_id" \
  --snapshot-type manual \
  --query "DBSnapshots[0].Status" \
  --output text)

if [ "$status" != "available" ]; then
  echo "ERROR: snapshot ${snapshot_id} did not reach 'available' (status: ${status})." >&2
  exit 1
fi

echo ""
echo "Backup complete: ${snapshot_id} (available)"

# Surface the snapshot id to downstream steps / the action output, if the runner
# provided an output file.
if [ -n "${NUON_ACTIONS_OUTPUT_FILEPATH:-}" ]; then
  echo "RDS_BACKUP_SNAPSHOT_ID=${snapshot_id}" >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
fi
