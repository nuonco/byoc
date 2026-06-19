#!/usr/bin/env bash
#
# runner-sa-unique-id
#
# Prints the numeric uniqueId (OIDC 'sub') of the install's runner GCP service
# account. This is the value that goes in mono/infra/byoc-secrets'
# gcp_installs[...].gcp_service_account_unique_id, used to bind the federated
# AWS reader role's trust policy.
#
# Required env:
#   RUNNER_SA_EMAIL  the runner service account email (interpolated from the
#                    install stack's runner_service_account_email output).
set -euo pipefail

if [[ -z "${RUNNER_SA_EMAIL:-}" ]]; then
  echo "RUNNER_SA_EMAIL is empty (install stack output not populated yet?)." >&2
  exit 1
fi

echo "runner service account: $RUNNER_SA_EMAIL" >&2

UNIQUE_ID=$(gcloud iam service-accounts describe "$RUNNER_SA_EMAIL" \
  --format='value(uniqueId)')

if [[ -z "$UNIQUE_ID" ]]; then
  echo "could not resolve uniqueId for $RUNNER_SA_EMAIL" >&2
  exit 1
fi

echo "$UNIQUE_ID"

# Surface it as an action output too, so it shows up in the run's outputs.
jq --null-input --arg id "$UNIQUE_ID" '{"unique_id": $id}' >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
