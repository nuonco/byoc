#!/usr/bin/env bash

# lists image tags for the public ECR repo provisioned by the
# `runner_repository` component (0-tf-runner-repository.toml).
#
# ECR Public lives in us-east-1 regardless of install region.

set -e
set -o pipefail
set -u

export AWS_PAGER=""
unset AWS_REGION

REPOSITORY_NAME="${REPOSITORY_NAME:-runner}"
LIMIT="${LIMIT:-20}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "repository: $REPOSITORY_NAME"
echo "region:     $AWS_REGION"
echo "limit:      $LIMIT"
echo

raw=$(aws ecr-public describe-images \
  --repository-name "$REPOSITORY_NAME" \
  --region "$AWS_REGION" \
  --output json)

tags=$(echo "$raw" | jq --argjson limit "$LIMIT" '
  [
    .imageDetails[]
    | select(.imageTags != null)
    | . as $img
    | .imageTags[]
    | {
        key: .,
        value: {
          pushed_at: $img.imagePushedAt,
          digest:    $img.imageDigest,
          size:      $img.imageSizeInBytes
        }
      }
  ]
  | sort_by(.value.pushed_at) | reverse
  | .[0:$limit]
  | from_entries
')

echo "$tags" > "$NUON_ACTIONS_OUTPUT_FILEPATH"
echo "$tags" | jq -r 'to_entries[] | "\(.value.pushed_at)  \(.key)"'
