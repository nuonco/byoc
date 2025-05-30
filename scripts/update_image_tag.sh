#!/bin/bash

# Script to update semver number in TOML file
# Usage: ./update_toml_version.sh <file_path> <semver>
# Example: ./update_toml_version.sh "config.toml" "1.2.3"

if [ $# -ne 2 ]; then
    echo "Usage: $0 <file_path> <semver>"
    echo "Example: $0 \"config.toml\" \"1.2.3\""
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

# Replace the version number using sed (compatible with both macOS and Linux)
# Pattern matches: tag followed by any amount of whitespace, =, whitespace, and quoted version
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS requires a backup extension with -i
    sed -i.tmp "s/^tag[[:space:]]*=[[:space:]]*\"[^\"]*\"$/tag          = \"$SEMVER\"/" "$FILE_PATH"
    rm -f "${FILE_PATH}.tmp"
else
    # Linux allows -i without extension
    sed -i "s/^tag[[:space:]]*=[[:space:]]*\"[^\"]*\"$/tag          = \"$SEMVER\"/" "$FILE_PATH"
fi

# Verify the change was made
if grep -q "tag          = \"$SEMVER\"" "$FILE_PATH"; then
    echo "Successfully updated version to $SEMVER in $FILE_PATH"
else
    echo "Warning: Version may not have been updated in $FILE_PATH. Please check if the 'tag = \"...\"' line exists."
fi
