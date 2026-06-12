#!/usr/bin/env bash

set -e
set -o pipefail
set -u

# Lists the backups for both Cloud SQL instances (ctl-api/nuon and temporal).
#
# Required env:
#   DB_INSTANCE_NAME_CTL_API   the ctl-api (nuon) Cloud SQL instance name
#   DB_INSTANCE_NAME_TEMPORAL  the temporal Cloud SQL instance name
#   PROJECT_ID                 the GCP project id

project_id="$PROJECT_ID"

for instance in "$DB_INSTANCE_NAME_CTL_API" "$DB_INSTANCE_NAME_TEMPORAL"; do
  echo "==================================================================="
  echo " Cloud SQL backups: ${instance}"
  echo "==================================================================="
  gcloud sql backups list \
    --instance "$instance" \
    --project "$project_id"
  echo
done
