#!/bin/bash

# Script to update the Karpenter EC2NodeClass AMI alias version
# Usage: ./update_ami_alias.sh <version>
# Example: ./update_ami_alias.sh "v20260520"

set -euo pipefail

FILE_PATH="byoc-nuon/inputs/karpenter/karpenter_ami_alias.toml"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 \"v20260520\""
    exit 1
fi

VERSION="$1"

if [ ! -f "$FILE_PATH" ]; then
    echo "Error: File '$FILE_PATH' not found!"
    exit 1
fi

# Expect a Karpenter AL2023 AMI release tag like vYYYYMMDD
if ! echo "$VERSION" | grep -qE '^v[0-9]{8}$'; then
    echo "Error: '$VERSION' is not a valid AL2023 AMI release tag (expected: vYYYYMMDD)"
    exit 1
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i.tmp -E "s|(default[[:space:]]*=[[:space:]]*\"al2023@)v[0-9]{8}(\")|\1${VERSION}\2|" "$FILE_PATH"
    rm -f "${FILE_PATH}.tmp"
else
    sed -i -E "s|(default[[:space:]]*=[[:space:]]*\"al2023@)v[0-9]{8}(\")|\1${VERSION}\2|" "$FILE_PATH"
fi

if grep -q "al2023@${VERSION}" "$FILE_PATH"; then
    echo "Successfully updated AMI alias to al2023@${VERSION} in $FILE_PATH"
else
    echo "Warning: AMI alias may not have been updated in $FILE_PATH. Please check the file."
    exit 1
fi
