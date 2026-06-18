#!/usr/bin/env bash
#
# sync-slack-secrets (GCP)
#
# Reads the central Slack secret (JSON with client_secret and signing_secret)
# from the central AWS Secrets Manager (byoc-infra-prod), writes it to the
# install's ctl-api namespace as ctl-api-slack-{client,signing}-secret, then
# restarts the api-slack deployment.
#
# Unlike the AWS install (whose maintenance IAM role is granted on the secret
# directly), a GCP install has no AWS identity. Instead it federates: the
# runner mints a Google-signed OIDC token for its GCP identity (the
# <install_id>-maintenance service account, via the GCE/GKE metadata server)
# and exchanges it for temporary AWS credentials via
# sts:AssumeRoleWithWebIdentity against a per-install IAM role whose trust
# policy is bound to that GCP service account. That role is what the central
# secret's resource policy and CMK key policy grant.
#
# state_jwt is intentionally left alone — it's auto-generated and
# kubernetes-synced by the Nuon platform.
#
# Required env:
#   SLACK_SECRETS_ARN       - full ARN of the central secret. Empty => skip (no-op).
#   SLACK_SECRETS_ROLE_ARN  - AWS IAM role to assume via web identity.
#   SLACK_SECRETS_AUDIENCE  - OIDC audience the role's trust policy expects.
#   NAMESPACE               - k8s namespace for ctl-api (default ctl-api).
#   INSTALL_ID              - used for the STS role session name.
set -euo pipefail
set -o errtrace

: "${NAMESPACE:=ctl-api}"
: "${SLACK_SECRETS_AUDIENCE:=sts.amazonaws.com}"

if [[ -z "${SLACK_SECRETS_ARN:-}" ]]; then
  echo "SLACK_SECRETS_ARN is empty; Slack is not enabled for this install. Nothing to do."
  exit 0
fi

if [[ -z "${SLACK_SECRETS_ROLE_ARN:-}" ]]; then
  echo "SLACK_SECRETS_ROLE_ARN is empty; cannot federate into AWS to read the secret." >&2
  exit 1
fi

# Region is encoded in the ARN: arn:aws:secretsmanager:<region>:<acct>:secret:<name>-<suffix>
SECRETS_REGION=$(echo "$SLACK_SECRETS_ARN" | awk -F: '{print $4}')
if [[ -z "$SECRETS_REGION" ]]; then
  echo "could not parse region from SLACK_SECRETS_ARN: $SLACK_SECRETS_ARN" >&2
  exit 1
fi

# 1. Mint a Google-signed OIDC identity token for this runner's GCP identity.
#    Same metadata endpoint the runner uses internally (pkg/gcp identity.go).
echo "minting GCP identity token (audience: $SLACK_SECRETS_AUDIENCE)"
WEB_IDENTITY_TOKEN=$(curl -sf -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity?audience=${SLACK_SECRETS_AUDIENCE}&format=full")
if [[ -z "$WEB_IDENTITY_TOKEN" ]]; then
  echo "failed to mint GCP identity token from the metadata server" >&2
  exit 1
fi

# 2. Exchange it for temporary AWS credentials (no pre-existing AWS creds needed).
echo "assuming AWS role via web identity"
echo "  role:   $SLACK_SECRETS_ROLE_ARN"
echo "  region: $SECRETS_REGION"
CREDS=$(aws --region "$SECRETS_REGION" sts assume-role-with-web-identity \
  --role-arn "$SLACK_SECRETS_ROLE_ARN" \
  --role-session-name "slack-sync-${INSTALL_ID:-nuon}" \
  --web-identity-token "$WEB_IDENTITY_TOKEN" \
  --query 'Credentials' --output json)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -er '.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -er '.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -er '.SessionToken')

# 3. Read the central secret with the temporary credentials.
echo "reading central Slack secret"
echo "  arn: $SLACK_SECRETS_ARN"
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
