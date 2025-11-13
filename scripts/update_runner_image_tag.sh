#!/bin/bash

# Script to update RUNNER_CONTAINER_IMAGE_TAG in YAML file
# Usage: ./update_runner_image_tag.sh <file_path> <semver>
# Example: ./update_runner_image_tag.sh "byoc-nuon/components/values/ctl-api.yaml" "0.19.690"

if [ $# -ne 2 ]; then
    echo "Usage: $0 <file_path> <semver>"
    echo "Example: $0 \"byoc-nuon/components/values/ctl-api.yaml\" \"0.19.690\""
    exit 1
fi

FILE_PATH="$1"
SEMVER="$2"

# Check if file exists
if [ ! -f "$FILE_PATH" ]; then
    echo "Error: File '$FILE_PATH' not found!"
    exit 1
fi

# Validate semver format (basic check for x.y.z pattern)
if ! echo "$SEMVER" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$'; then
    echo "Error: '$SEMVER' is not a valid semver format (expected: x.y.z)"
    exit 1
fi

# Replace the RUNNER_CONTAINER_IMAGE_TAG value using sed (compatible with both macOS and Linux)
# Pattern matches: RUNNER_CONTAINER_IMAGE_TAG followed by colon, whitespace, and quoted version
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS requires a backup extension with -i
    sed -i.tmp "s/^[[:space:]]*RUNNER_CONTAINER_IMAGE_TAG:[[:space:]]*\"[^\"]*\"$/  RUNNER_CONTAINER_IMAGE_TAG: \"$SEMVER\"/" "$FILE_PATH"
    rm -f "${FILE_PATH}.tmp"
else
    # Linux allows -i without extension
    sed -i "s/^[[:space:]]*RUNNER_CONTAINER_IMAGE_TAG:[[:space:]]*\"[^\"]*\"$/  RUNNER_CONTAINER_IMAGE_TAG: \"$SEMVER\"/" "$FILE_PATH"
fi

# Verify the change was made
if grep -q "RUNNER_CONTAINER_IMAGE_TAG: \"$SEMVER\"" "$FILE_PATH"; then
    echo "Successfully updated RUNNER_CONTAINER_IMAGE_TAG to $SEMVER in $FILE_PATH"
else
    echo "Warning: RUNNER_CONTAINER_IMAGE_TAG may not have been updated in $FILE_PATH. Please check if the 'RUNNER_CONTAINER_IMAGE_TAG: \"...\"' line exists."
fi
