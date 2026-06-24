#!/bin/bash

# Validate that a Karpenter AL2023 AMI alias resolves to a real EKS-optimized AMI.
#
# Karpenter resolves the `al2023@vYYYYMMDD` alias by looking up the EKS SSM
# public parameter:
#   /aws/service/eks/optimized-ami/<k8s>/amazon-linux-2023/<arch>/<variant>/amazon-eks-node-al2023-<arch>-<variant>-<k8s>-<version>/image_id
# This script does the same lookup with the local AWS CLI/creds and fails if the
# parameter does not resolve to an AMI id. Use it to gate the update workflow
# before opening a bump PR (pairs with .github/workflows/update_ami_alias.yml).
#
# Usage: ./scripts/validate_ami_alias.sh [version]
#   version  AL2023 release tag (vYYYYMMDD) or full alias (al2023@vYYYYMMDD).
#            If omitted, it is read from the input TOML file.
#
# Environment overrides:
#   REGION        AWS region(s), space/comma separated (default: us-east-1)
#   K8S_VERSION   EKS minor version (default: cluster_version from sandbox.toml)
#   ARCH          CPU arch (default: x86_64)
#   VARIANT       AMI variant (default: standard)

set -euo pipefail

FILE_PATH="byoc-nuon/inputs/karpenter/karpenter_ami_alias.toml"
SANDBOX_PATH="byoc-nuon/sandbox.toml"

REGION="${REGION:-us-east-1}"
ARCH="${ARCH:-x86_64}"
VARIANT="${VARIANT:-standard}"

# Resolve the version: from the first arg, or from the input file.
if [ $# -ge 1 ]; then
    VERSION="$1"
else
    if [ ! -f "$FILE_PATH" ]; then
        echo "Error: File '$FILE_PATH' not found and no version argument given."
        exit 1
    fi
    VERSION=$(grep -oE 'al2023@v[0-9]{8}' "$FILE_PATH" | head -1 | cut -d'@' -f2)
fi

# Accept either "al2023@v20260520" or "v20260520".
VERSION="${VERSION#al2023@}"

if ! echo "$VERSION" | grep -qE '^v[0-9]{8}$'; then
    echo "Error: '$VERSION' is not a valid AL2023 AMI release tag (expected: vYYYYMMDD)"
    exit 1
fi

# Derive the EKS minor version from the sandbox input unless overridden.
if [ -z "${K8S_VERSION:-}" ]; then
    if [ -f "$SANDBOX_PATH" ]; then
        K8S_VERSION=$(grep -E '^cluster_version' "$SANDBOX_PATH" | head -1 | sed -E 's/.*"([0-9]+\.[0-9]+)".*/\1/')
    fi
fi
if [ -z "${K8S_VERSION:-}" ]; then
    echo "Error: could not determine K8S_VERSION (not in $SANDBOX_PATH and not set in env)."
    exit 1
fi

# AWS CLI sanity check.
if ! command -v aws >/dev/null 2>&1; then
    echo "Error: aws CLI not found on PATH."
    exit 1
fi
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "Error: unable to call AWS with current credentials (run 'aws sso login' or set creds)."
    exit 1
fi

echo "Validating AL2023 AMI alias al2023@${VERSION}"
echo "  k8s=${K8S_VERSION} arch=${ARCH} variant=${VARIANT}"
echo

PARAM_NAME="/aws/service/eks/optimized-ami/${K8S_VERSION}/amazon-linux-2023/${ARCH}/${VARIANT}/amazon-eks-node-al2023-${ARCH}-${VARIANT}-${K8S_VERSION}-${VERSION}/image_id"

failed=0
# Split REGION on spaces and commas.
for region in $(echo "$REGION" | tr ',' ' '); do
    ami_id=$(aws ssm get-parameter \
        --name "$PARAM_NAME" \
        --region "$region" \
        --query 'Parameter.Value' \
        --output text 2>/dev/null || true)

    if echo "$ami_id" | grep -qE '^ami-[0-9a-f]+$'; then
        echo "✅ ${region}: al2023@${VERSION} -> ${ami_id}"
    else
        echo "❌ ${region}: no AMI for al2023@${VERSION} (SSM parameter not found)"
        echo "     param: ${PARAM_NAME}"
        failed=1
    fi
done

echo
if [ "$failed" -ne 0 ]; then
    echo "AMI alias validation FAILED."
    exit 1
fi
echo "AMI alias validation passed."
