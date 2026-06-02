#!/usr/bin/env bash
#
# sync-slack-secrets
#
# Reads the central Slack secret (JSON with client_secret and signing_secret)
# from infra-shared-prod's AWS Secrets Manager, writes it to the install's
# ctl-api namespace as ctl-api-slack-{client,signing}-secret, then restarts
# the api-slack deployment.
#
# state_jwt is intentionally left alone — it's auto-generated and
# kubernetes-synced by the Nuon platform.
#
# Required env:
#   SLACK_SECRETS_ARN  - full ARN of the central secret. Empty => skip (no-op).
#   NAMESPACE          - k8s namespace for ctl-api (default ctl-api).
#
# Cross-account reads do not need explicit assume-role. The install's
# maintenance role has secretsmanager:GetSecretValue + kms:Decrypt on "*";
# the central secret's resource policy and the CMK's key policy allow this
# role by ARN.
set -euo pipefail
set -o errtrace

: "${NAMESPACE:=ctl-api}"

if [[ -z "${SLACK_SECRETS_ARN:-}" ]]; then
  echo "SLACK_SECRETS_ARN is empty; Slack is not enabled for this install. Nothing to do."
  exit 0
fi

# Region is encoded in the ARN: arn:aws:secretsmanager:<region>:<acct>:secret:<name>-<suffix>
SECRETS_REGION=$(echo "$SLACK_SECRETS_ARN" | awk -F: '{print $4}')
if [[ -z "$SECRETS_REGION" ]]; then
  echo "could not parse region from SLACK_SECRETS_ARN: $SLACK_SECRETS_ARN" >&2
  exit 1
fi

echo "reading central Slack secret"
echo "  arn:    $SLACK_SECRETS_ARN"
echo "  region: $SECRETS_REGION"

VALUE=$(aws --region "$SECRETS_REGION" secretsmanager get-secret-value \
  --secret-id "$SLACK_SECRETS_ARN" \
  --query SecretString --output text)

CLIENT_SECRET=$(echo "$VALUE" | jq -er '.client_secret')
SIGNING_SECRET=$(echo "$VALUE" | jq -er '.signing_secret')

if [[ -z "$CLIENT_SECRET" || -z "$SIGNING_SECRET" ]]; then
  echo "central secret missing client_secret or signing_secret fields" >&2
  exit 1
fi

apply_secret() {
  local name="$1" value="$2"
  echo "applying secret $NAMESPACE/$name"
  # --dry-run=client | apply keeps this idempotent without leaking value to argv
  kubectl create secret generic "$name" \
    -n "$NAMESPACE" \
    --from-literal=value="$value" \
    --dry-run=client -o yaml \
    | kubectl apply -f -
}

apply_secret ctl-api-slack-client-secret  "$CLIENT_SECRET"
apply_secret ctl-api-slack-signing-secret "$SIGNING_SECRET"

# Restart api-slack so it re-reads the secret values.
# Matches whatever the chart fullname renders to; -l label is more durable
# than a hard-coded deployment name across chart-version bumps.
if kubectl -n "$NAMESPACE" get deploy -l app.nuon.co/name=ctl-api-slack -o name | grep -q deploy; then
  echo "restarting api-slack deployment"
  kubectl -n "$NAMESPACE" rollout restart deploy -l app.nuon.co/name=ctl-api-slack
else
  echo "no api-slack deployment found in $NAMESPACE; secrets applied, restart skipped"
fi

echo "done"
