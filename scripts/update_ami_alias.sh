#!/bin/bash

# Script to update the Karpenter AL2023 AMI alias version in a file.
# Rewrites any "al2023@vYYYYMMDD" token, so it works on both the input
# default (default = "al2023@v...") and the nodeclass template (alias: "al2023@v...").
# Usage: ./update_ami_alias.sh <file_path> <version>
# Example: ./update_ami_alias.sh "byoc-nuon/inputs/karpenter/karpenter_ami_alias.toml" "v20260520"

set -euo pipefail

if [ $# -ne 2 ]; then
    echo "Usage: $0 <file_path> <version>"
    echo "Example: $0 \"byoc-nuon/inputs/karpenter/karpenter_ami_alias.toml\" \"v20260520\""
    exit 1
fi

FILE_PATH="$1"
VERSION="$2"

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
    sed -i.tmp -E "s|(al2023@)v[0-9]{8}|\1${VERSION}|" "$FILE_PATH"
    rm -f "${FILE_PATH}.tmp"
else
    sed -i -E "s|(al2023@)v[0-9]{8}|\1${VERSION}|" "$FILE_PATH"
fi

if grep -q "al2023@${VERSION}" "$FILE_PATH"; then
    echo "Successfully updated AMI alias to al2023@${VERSION} in $FILE_PATH"
else
    echo "Warning: AMI alias may not have been updated in $FILE_PATH. Please check the file."
    exit 1
fi
