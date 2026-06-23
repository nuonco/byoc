#!/usr/bin/env bash
#
# s3_bucket / inspect (GCP)
#
# Inspects the AWS S3 install-stack template bucket
# (install_stack_template_bucket) — the bucket the ctl-api uses to hold the
# CloudFormation install-stack templates for the AWS installs this control
# plane manages. Prints the bucket name, region, a little metadata (versioning
# + default encryption), and lists up to 5 objects.
#
# A GCP install has no AWS identity, so — exactly like the sync_slack_secrets
# action — it federates: the runner mints a Google-signed OIDC token for its
# GCP identity (via the metadata server) and exchanges it for temporary AWS
# credentials via sts:AssumeRoleWithWebIdentity against the bucket's role
# (install_stack_template_bucket_role_arn). That role must grant
# s3:GetBucket*/s3:ListBucket on the bucket for this action to succeed;
# otherwise the AWS calls fail with AccessDenied.
# See docs/aws-gcp-identity-federation.md.
#
# Required env:
#   BUCKET         - the S3 bucket name. Empty => skip (no-op).
#   ROLE_ARN       - AWS IAM role to assume via web identity
#                    (install_stack_template_bucket_role_arn). Empty => error.
#   AUDIENCE       - OIDC audience the role's trust policy expects (sts.amazonaws.com).
#   INSTALL_ID     - used for the STS role session name.
# Optional env:
#   BUCKET_REGION  - the bucket's region (from install_stack_template_bucket_region).
#                    Used for the initial API region; falls back to us-east-1.
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

# Region used for the initial STS/S3 calls. S3 is global for naming but the API
# wants a region; the bucket's real region is reported below via get-bucket-location.
region="${BUCKET_REGION:-us-east-1}"
[[ -z "$region" ]] && region="us-east-1"

# 1. Mint a Google-signed OIDC identity token for this runner's GCP identity.
echo "minting GCP identity token (audience: $AUDIENCE)"
WEB_IDENTITY_TOKEN=$(curl -sf -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity?audience=${AUDIENCE}&format=full")
if [[ -z "$WEB_IDENTITY_TOKEN" ]]; then
  echo "failed to mint GCP identity token from the metadata server" >&2
  exit 1
fi

# 2. Exchange it for temporary AWS credentials (no pre-existing AWS creds needed).
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
