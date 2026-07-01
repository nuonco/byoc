#!/usr/bin/env bash
#
# s3_bucket / inspect (GCP)
#
# Inspects the AWS S3 install-stack template bucket
# (install_stack_template_bucket) — the bucket ctl-api uploads CloudFormation
# install-stack templates to for the AWS installs this GCP control plane
# manages. Prints the bucket name, region, a little metadata (versioning +
# default encryption), and lists up to 5 objects.
#
# IDENTITY: a GCP install has no AWS identity, so it federates — mint a
# Google-signed OIDC token, exchange it via sts:AssumeRoleWithWebIdentity for
# temporary AWS credentials against install_stack_template_bucket_role_arn.
# That role's trust policy is scoped to the *ctl-api* service account's
# unique_id (from ctl_api_wi) — because in production it's ctl-api, not the
# runner, that uploads templates. This action runs on the runner, whose own
# identity (runner_service_account_email) is NOT trusted by the role.
#
# So we IMPERSONATE ctl-api: the runner SA is granted token-creator on the
# ctl-api SA (ctl_api_wi.runner_impersonate_ctl_api), and we ask the IAM
# Credentials API to mint an OIDC ID token AS ctl-api (sub = ctl-api's
# unique_id). That token matches the role's trust policy, so the assume-role
# succeeds — verifying the exact federation path ctl-api uses in production.
#
# The role must grant s3:GetBucket*/s3:ListBucket on the bucket; otherwise the
# AWS calls fail with AccessDenied.
#
# Required env:
#   BUCKET            - the S3 bucket name. Empty => skip (no-op).
#   ROLE_ARN          - install_stack_template_bucket_role_arn. Empty => error.
#   CTL_API_SA_EMAIL  - ctl-api service account email (ctl_api_wi output) to
#                       impersonate. Empty => error.
#   AUDIENCE          - OIDC audience the role's trust policy expects (sts.amazonaws.com).
#   INSTALL_ID        - used for the STS role session name.
# Optional env:
#   BUCKET_REGION     - the bucket's region (install_stack_template_bucket_region).
#                       Used for the initial API region; falls back to us-east-1.
set -euo pipefail
set -o errtrace

: "${AUDIENCE:=sts.amazonaws.com}"

if [[ -z "${BUCKET:-}" ]]; then
  echo "BUCKET (install_stack_template_bucket) is empty; nothing to inspect. Nothing to do."
  exit 0
fi

if [[ -z "${ROLE_ARN:-}" ]]; then
  echo "ROLE_ARN (install_stack_template_bucket_role_arn) is empty; cannot federate into AWS to read the bucket." >&2
  exit 1
fi

if [[ -z "${CTL_API_SA_EMAIL:-}" ]]; then
  echo "CTL_API_SA_EMAIL is empty; cannot impersonate ctl-api to mint a trusted token. Deploy ctl_api_wi first." >&2
  exit 1
fi

# Region used for the initial STS/S3 calls. S3 is global for naming but the API
# wants a region; the bucket's real region is reported below via get-bucket-location.
region="${BUCKET_REGION:-us-east-1}"
[[ -z "$region" ]] && region="us-east-1"

# ── 1. mint a Google OIDC token AS ctl-api (impersonation) ────────────────────
# The runner SA calls IAM Credentials generateIdToken on the ctl-api SA; the
# resulting token's sub is ctl-api's unique_id — what the role trusts.
echo "minting OIDC token as ctl-api SA via impersonation (audience: $AUDIENCE)"
echo "  ctl-api SA: $CTL_API_SA_EMAIL"
WEB_IDENTITY_TOKEN=$(gcloud auth print-identity-token \
  --impersonate-service-account="$CTL_API_SA_EMAIL" \
  --audiences="$AUDIENCE" \
  --include-email 2>/dev/null || true)

if [[ -z "$WEB_IDENTITY_TOKEN" ]]; then
  echo "ERROR: failed to mint an identity token as ctl-api." >&2
  echo "Check that ctl_api_wi has been deployed (it grants the runner SA" >&2
  echo "roles/iam.serviceAccountTokenCreator on $CTL_API_SA_EMAIL)." >&2
  exit 1
fi

# ── 2. exchange the ctl-api token for temporary AWS credentials ───────────────
echo "assuming AWS role via web identity"
echo "  role:   $ROLE_ARN"
echo "  region: $region"
CREDS=$(aws --region "$region" sts assume-role-with-web-identity \
  --role-arn "$ROLE_ARN" \
  --role-session-name "s3-bucket-inspect-${INSTALL_ID:-nuon}" \
  --web-identity-token "$WEB_IDENTITY_TOKEN" \
  --query 'Credentials' --output json)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -er '.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -er '.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -er '.SessionToken')

echo
echo "==================================================================="
echo " S3 bucket inspection: ${BUCKET}"
echo "==================================================================="

# Region: get-bucket-location returns LocationConstraint, which is null/empty
# for us-east-1.
location=$(aws --region "$region" s3api get-bucket-location \
  --bucket "$BUCKET" --query 'LocationConstraint' --output text 2>/dev/null || echo "")
[[ -z "$location" || "$location" == "None" ]] && location="us-east-1"

echo "bucket=${BUCKET}  region=${location}  configured_region=${BUCKET_REGION:-<unset>}"
echo

echo "### Versioning"
aws --region "$location" s3api get-bucket-versioning --bucket "$BUCKET" || true
echo

echo "### Default encryption"
aws --region "$location" s3api get-bucket-encryption --bucket "$BUCKET" \
  --query 'ServerSideEncryptionConfiguration.Rules' 2>/dev/null \
  || echo "(no default encryption configured, or access denied)"
echo

echo "### Objects (up to 5)"
aws --region "$location" s3api list-objects-v2 \
  --bucket "$BUCKET" \
  --max-items 5 \
  --query 'Contents[].{Key:Key,Size:Size,LastModified:LastModified,StorageClass:StorageClass}' \
  --output table \
  || echo "(no objects, or access denied)"

echo
echo "done"
