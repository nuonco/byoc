#!/usr/bin/env bash

set -e
set -o pipefail
set -u

# Deletes a single RDS instance via the AWS API, taking a final snapshot as part
# of the delete. This is the explicit destruction step of an RDS teardown
# runbook: it is intentionally decoupled from the Terraform deploy/teardown job
# so deleting the database is always a deliberate, audited action rather than a
# side effect of a plan.
#
# Required env:
#   DB_RESOURCE_ID  the stable DbiResourceId of the instance
#                   (rds_cluster_*.outputs.db_instance_resource_id)
# Optional env:
#   DB_LABEL          human-friendly label used in log output (defaults to "database")
#   SNAPSHOT_SUFFIX   suffix used in the final snapshot id (defaults to "final")

export AWS_PAGER=""

db_resource_id="$DB_RESOURCE_ID"
db_label="${DB_LABEL:-database}"
snapshot_suffix="${SNAPSHOT_SUFFIX:-final}"

echo "==================================================================="
echo " RDS delete: ${db_label}  (resource id: ${db_resource_id})"
echo "==================================================================="

# Resolve the human instance identifier from the stable resource id.
db_instance_id=$(aws rds describe-db-instances \
  --query "DBInstances[?DbiResourceId=='${db_resource_id}'].DBInstanceIdentifier" \
  --output text)

if [ -z "$db_instance_id" ] || [ "$db_instance_id" = "None" ]; then
  echo "Instance with DbiResourceId='${db_resource_id}' not found — already deleted. Nothing to do."
  exit 0
fi

echo "Instance: ${db_instance_id}"

# Refuse to delete a deletion-protected instance: we deliberately do NOT hold
# rds:ModifyDBInstance, so protection must be cleared via the normal config path.
protected=$(aws rds describe-db-instances \
  --db-instance-identifier "$db_instance_id" \
  --query "DBInstances[0].DeletionProtection" \
  --output text)

if [ "$protected" = "True" ]; then
  echo "ERROR: ${db_instance_id} has deletion protection enabled." >&2
  echo "Disable deletion_protection on the component and redeploy before running this action." >&2
  exit 1
fi

# Final snapshot id: start with a letter, alphanumeric + single hyphens, no
# trailing hyphen. The instance id already satisfies this; append a stamped suffix.
stamp=$(date -u +%Y%m%d-%H%M%S)
snapshot_id="${db_instance_id}-${snapshot_suffix}-${stamp}"

echo ""
echo "Deleting instance ${db_instance_id} with final snapshot ${snapshot_id}..."
aws rds delete-db-instance \
  --db-instance-identifier "$db_instance_id" \
  --final-db-snapshot-identifier "$snapshot_id" \
  --delete-automated-backups >/dev/null

echo "Waiting for instance to be deleted (this can take several minutes)..."
aws rds wait db-instance-deleted \
  --db-instance-identifier "$db_instance_id"

echo ""
echo "Instance ${db_instance_id} deleted. Final snapshot: ${snapshot_id}"
echo "NOTE: the Terraform component still references this instance in its state."
echo "      Detaching it from state is a separate step (not yet automated)."

# Surface the final snapshot id to downstream steps / the action output.
if [ -n "${NUON_ACTIONS_OUTPUT_FILEPATH:-}" ]; then
  echo "RDS_FINAL_SNAPSHOT_ID=${snapshot_id}" >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
fi
