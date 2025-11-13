#!/bin/bash
set -e

# Extract tag from TOML file
TOML_TAG=$(grep '^tag' byoc-nuon/components/4-image-nuon_ctl_api.toml | sed 's/tag[[:space:]]*=[[:space:]]*"\(.*\)"/\1/')

# Extract tag from YAML file
YAML_TAG=$(grep 'RUNNER_CONTAINER_IMAGE_TAG:' byoc-nuon/components/values/ctl-api.yaml | sed 's/.*RUNNER_CONTAINER_IMAGE_TAG:[[:space:]]*"\(.*\)"/\1/')

echo "TOML tag: $TOML_TAG"
echo "YAML tag: $YAML_TAG"

# Set outputs for GitHub Actions
echo "toml_tag=$TOML_TAG" >> $GITHUB_OUTPUT
echo "yaml_tag=$YAML_TAG" >> $GITHUB_OUTPUT

# Compare tags
if [ "$TOML_TAG" != "$YAML_TAG" ]; then
  echo "tags_match=false" >> $GITHUB_OUTPUT
  echo "❌ Tags do not match!"
  exit 0
else
  echo "tags_match=true" >> $GITHUB_OUTPUT
  echo "✅ Tags match!"
fi
