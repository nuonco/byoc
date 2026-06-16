#!/bin/bash
#
# Local-use script. Validates that a Karpenter AL2023 AMI alias version actually
# resolves to a real Amazon EKS-optimized AMI via the AWS CLI (SSM public
# parameters). Karpenter resolves a pinned al2023 alias to the SSM parameter:
#
#   /aws/service/eks/optimized-ami/<k8s>/amazon-linux-2023/x86_64/standard/\
#     amazon-eks-node-al2023-x86_64-standard-<k8s>-<version>/image_id
#
# The k8s version is read from byoc-nuon/sandbox.toml (cluster_version) and the
# architecture is x86_64 (all karpenter nodepools use c5/m6a instances).
#
# Usage: ./validate_ami_alias.sh [version]
#   version   Optional. "v20260520" or "al2023@v20260520". Defaults to the
#             `default` in byoc-nuon/inputs/karpenter/karpenter_ami_alias.toml.
#
# Requires: aws CLI with credentials and a default region configured.

set -euo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    sed -n '2,20p' "$0"
    exit 0
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
input_file="$repo_root/byoc-nuon/inputs/karpenter/karpenter_ami_alias.toml"
sandbox_file="$repo_root/byoc-nuon/sandbox.toml"

if ! command -v aws >/dev/null 2>&1; then
    echo "Error: aws CLI not found on PATH." >&2
    exit 1
fi

# Resolve the version to validate: arg, else the toml input default.
if [ $# -ge 1 ]; then
    raw="$1"
else
    raw=$(grep -oE 'al2023@v[0-9]{8}' "$input_file" | head -1)
    if [ -z "$raw" ]; then
        echo "Error: could not read alias default from $input_file" >&2
        exit 1
    fi
fi

# Strip any al2023@ prefix, then validate the vYYYYMMDD shape.
version="${raw#al2023@}"
if ! echo "$version" | grep -qE '^v[0-9]{8}$'; then
    echo "Error: '$raw' is not a valid AL2023 alias version (expected: vYYYYMMDD or al2023@vYYYYMMDD)" >&2
    exit 1
fi

# k8s version from the sandbox config so it stays in sync with the cluster.
k8s_version=$(awk -F'"' '/^cluster_version[[:space:]]*=/{print $2; exit}' "$sandbox_file")
if [ -z "$k8s_version" ]; then
    echo "Error: could not read cluster_version from $sandbox_file" >&2
    exit 1
fi

arch="x86_64"
variant="standard"
ami_name="amazon-eks-node-al2023-${arch}-${variant}-${k8s_version}-${version}"
ssm_path="/aws/service/eks/optimized-ami/${k8s_version}/amazon-linux-2023/${arch}/${variant}/${ami_name}/image_id"

region=$(aws configure list 2>/dev/null | awk '/region/{print $2}')
echo "Validating alias  : al2023@${version}"
echo "k8s version       : ${k8s_version} (from sandbox.toml)"
echo "architecture      : ${arch}"
echo "region            : ${region:-<default>}"
echo "SSM parameter     : ${ssm_path}"
echo

if ami_id=$(aws ssm get-parameter --name "$ssm_path" --query 'Parameter.Value' --output text 2>/dev/null); then
    echo "✅ Valid: al2023@${version} resolves to ${ami_id}"
    exit 0
else
    echo "❌ Invalid: al2023@${version} did not resolve (no EKS-optimized AMI published" >&2
    echo "   for k8s ${k8s_version}/${arch}). Check the version or your AWS region/creds." >&2
    exit 1
fi
