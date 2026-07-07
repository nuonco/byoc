#!/usr/bin/env bash

set -e
set -o pipefail
set -u

# Restores a Cloud SQL instance to a point in time using point-in-time recovery
# (PITR), which must be enabled on the source instance (it is: see the
# backup_configuration block in the cloudsql_* components).
#
# GCP note: PITR restore is NOT in-place. `gcloud sql instances clone` replays
# the source instance's archived transaction logs up to the requested timestamp
# into a BRAND NEW target instance, leaving the source untouched. Recovery is
# therefore a two-part operation: (1) this action creates the recovered instance;
# (2) repointing the application at it (or promoting/renaming) is a separate,
# deliberate step. We never mutate the live instance here.
#
# The point in time must fall within the transaction-log retention window
# (transaction_log_retention_days on the source, default 7) and cannot be in the
# future. Timestamps are RFC 3339 UTC, e.g. 2026-07-06T14:30:00Z.
#
# Required env:
#   SOURCE_INSTANCE_NAME  the Cloud SQL instance to recover from
#   POINT_IN_TIME         RFC 3339 UTC timestamp to restore to (e.g. 2026-07-06T14:30:00Z)
#   PROJECT_ID            the GCP project id
# Optional env:
#   TARGET_INSTANCE_NAME  name of the new recovered instance
#                         (defaults to "<source>-pitr-<YYYYmmdd-HHMMSS>")
#   DB_LABEL              human-friendly label used in log output (defaults to "database")
#   OVERRIDE_INPUT_NAME   the install input to set to the recovered address when
#                         repointing (defaults to "db_host_override"; temporal
#                         uses "temporal_db_host_override")

source_instance_name="$SOURCE_INSTANCE_NAME"
point_in_time="$POINT_IN_TIME"
project_id="$PROJECT_ID"
db_label="${DB_LABEL:-database}"
override_input_name="${OVERRIDE_INPUT_NAME:-db_host_override}"

stamp=$(date -u +%Y%m%d-%H%M%S)
target_instance_name="${TARGET_INSTANCE_NAME:-${source_instance_name}-pitr-${stamp}}"

echo "==================================================================="
echo " Cloud SQL PITR restore: ${db_label}"
echo "   source: ${source_instance_name}"
echo "   target: ${target_instance_name}  (new instance)"
echo "   point in time: ${point_in_time}"
echo "==================================================================="

# ── source must exist and have PITR enabled ──────────────────────────────────
if ! pitr_enabled=$(gcloud sql instances describe "$source_instance_name" \
  --project "$project_id" \
  --format='value(settings.backupConfiguration.pointInTimeRecoveryEnabled)' 2>/dev/null); then
  echo "ERROR: source instance ${source_instance_name} not found." >&2
  exit 1
fi

if [ "$pitr_enabled" != "True" ] && [ "$pitr_enabled" != "true" ]; then
  echo "ERROR: point-in-time recovery is not enabled on ${source_instance_name}." >&2
  echo "       PITR restore is impossible without archived transaction logs." >&2
  exit 1
fi

# ── refuse to clobber an existing target ─────────────────────────────────────
if gcloud sql instances describe "$target_instance_name" \
  --project "$project_id" --format='value(name)' >/dev/null 2>&1; then
  echo "ERROR: target instance ${target_instance_name} already exists." >&2
  echo "       Choose a different TARGET_INSTANCE_NAME or delete the existing one first." >&2
  exit 1
fi

echo ""
echo "Cloning ${source_instance_name} -> ${target_instance_name} at ${point_in_time}..."
gcloud sql instances clone "$source_instance_name" "$target_instance_name" \
  --project "$project_id" \
  --point-in-time "$point_in_time"

# Private IP of the recovered instance — this is what ctl-api's db_host_override
# input must be set to in order to repoint the app (see the PITR restore runbook).
recovered_address=$(gcloud sql instances describe "$target_instance_name" \
  --project "$project_id" \
  --format='value(ipAddresses[0].ipAddress)' 2>/dev/null || true)

echo ""
echo "Recovered instance ${target_instance_name} created from ${source_instance_name} at ${point_in_time}."
echo "  private address: ${recovered_address:-<unknown>}"
echo "NOTE: this is a NEW instance. The live instance ${source_instance_name} was not modified."
echo ""
echo "To repoint ${db_label} at the recovered instance:"
echo "  1. set the install input  ${override_input_name} = ${recovered_address:-<recovered address>}"
echo "  2. run the runbook's repoint step (redeploys the target component)."
echo "Clear the ${override_input_name} input and redeploy to revert to the Terraform-managed instance."

# Surface the recovered instance to downstream steps / the action output.
if [ -n "${NUON_ACTIONS_OUTPUT_FILEPATH:-}" ]; then
  echo "CLOUDSQL_PITR_TARGET_INSTANCE=${target_instance_name}" >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
  echo "CLOUDSQL_PITR_TARGET_ADDRESS=${recovered_address}" >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
fi
