#!/usr/bin/env bash

# empties the public ECR repo provisioned by the `runner_repository` component
# (0-tf-runner-repository.toml) by deleting all of its images, so the
# repository itself can then be torn down. Runs automatically as a
# pre-teardown-component hook for runner_repository.
#
# ECR Public lives in us-east-1 regardless of install region.

set -e
set -o pipefail
set -u

export AWS_PAGER=""

REPOSITORY_NAME="${REPOSITORY_NAME:-runner}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "repository: $REPOSITORY_NAME"
echo "region:     $AWS_REGION"
echo

# ECR Public has no list-images; describe-images returns imageDetails, one per
# image, covering both tagged and untagged images. Deleting by digest removes
# the image and all of its tags.
digests=$(aws ecr-public describe-images \
  --repository-name "$REPOSITORY_NAME" \
  --region "$AWS_REGION" \
  --query 'imageDetails[*].imageDigest' --output text)

if [ -z "$digests" ]; then
  echo "repository is already empty; nothing to delete"
  jq -cn --arg repo "$REPOSITORY_NAME" \
    '{repository: $repo, deleted: 0, failures: []}' \
    > "$NUON_ACTIONS_OUTPUT_FILEPATH"
  exit 0
fi

# digests are sha256:... tokens with no spaces or glob characters, so plain
# word-splitting into an array is safe.
# shellcheck disable=SC2206
digest_arr=($digests)
total=${#digest_arr[@]}
echo "found $total image(s) to delete"

deleted=0
failures="[]"

# batch-delete-image accepts at most 100 image IDs per call.
for ((i = 0; i < total; i += 100)); do
  image_ids=()
  for digest in "${digest_arr[@]:i:100}"; do
    image_ids+=("imageDigest=$digest")
  done

  echo "deleting images $((i + 1))-$((i + ${#image_ids[@]})) of $total"
  resp=$(aws ecr-public batch-delete-image \
    --repository-name "$REPOSITORY_NAME" \
    --region "$AWS_REGION" \
    --image-ids "${image_ids[@]}" \
    --output json)

  deleted=$((deleted + $(echo "$resp" | jq '.imageIds | length')))
  failures=$(jq -cn \
    --argjson acc "$failures" \
    --argjson new "$(echo "$resp" | jq '.failures')" \
    '$acc + $new')
done

result=$(jq -cn \
  --arg repo "$REPOSITORY_NAME" \
  --argjson deleted "$deleted" \
  --argjson failures "$failures" \
  '{repository: $repo, deleted: $deleted, failures: $failures}')
echo "$result" > "$NUON_ACTIONS_OUTPUT_FILEPATH"
echo "$result" | jq .

failed=$(echo "$failures" | jq 'length')
if [ "$failed" -gt 0 ]; then
  echo "completed with $failed failure(s)" >&2
  exit 1
fi

echo "successfully emptied repository: $REPOSITORY_NAME ($deleted image(s) deleted)"
