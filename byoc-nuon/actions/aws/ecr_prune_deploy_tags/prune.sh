#!/usr/bin/env bash

# deletes per-deploy tags from an install-registry ECR repo so pushes work again.

set -e
set -o pipefail
set -u

export AWS_PAGER=""

REPOSITORY_NAME="${REPOSITORY_NAME:-}"
AWS_REGION="${AWS_REGION:-}"
TAG_PREFIX="${TAG_PREFIX:-dpl}"
KEEP="${KEEP:-10}"
DRY_RUN="${DRY_RUN:-true}"

if [ -z "$REPOSITORY_NAME" ]; then
  echo "REPOSITORY_NAME is required" >&2
  exit 1
fi
if [ -z "$AWS_REGION" ]; then
  echo "AWS_REGION is required" >&2
  exit 1
fi

echo "repository: $REPOSITORY_NAME"
echo "region:     $AWS_REGION"
echo "prefix:     $TAG_PREFIX"
echo "keep:       $KEEP"
echo "dry run:    $DRY_RUN"
echo

raw=$(aws ecr describe-images \
  --repository-name "$REPOSITORY_NAME" \
  --region "$AWS_REGION" \
  --output json)

# Deleting every tag on a manifest deletes the image itself, so each manifest
# keeps at least one tag that does not match the prefix.
plan=$(echo "$raw" | jq -c \
  --arg prefix "$TAG_PREFIX" \
  --argjson keep "$KEEP" '
  [ .imageDetails[]
    | select(.imageTags != null)
    | (.imageTags | map(select(startswith($prefix))) | sort)         as $matched
    | (.imageTags | map(select(startswith($prefix) | not)) | length) as $other
    | ($matched | length)                                            as $n
    | (if $other > 0 then $keep else ($keep + 1) end)                as $reserve
    | { digest: .imageDigest,
        total: (.imageTags | length),
        matched: $n,
        delete: (if $n > $reserve then $matched[0:($n - $reserve)] else [] end) }
  ]')

echo "$plan" | jq -r '
  .[]
  | select((.delete | length) > 0)
  | "manifest \(.digest[0:19])  tags=\(.total)  matching=\(.matched)  to_delete=\(.delete | length)",
    (.delete[] | "    \(.)")'

echo "manifests with nothing to delete: $(echo "$plan" | jq '[.[] | select((.delete | length) == 0)] | length')"

tags=$(echo "$plan" | jq -c '[.[].delete[]]')
total=$(echo "$tags" | jq 'length')
echo
echo "tags to delete: $total"

if [ "$DRY_RUN" != "false" ]; then
  jq -cn --arg repo "$REPOSITORY_NAME" --argjson n "$total" --argjson tags "$tags" \
    '{repository: $repo, dry_run: true, would_delete: $n, tags: $tags}' \
    > "$NUON_ACTIONS_OUTPUT_FILEPATH"
  echo "dry run, nothing deleted. set DRY_RUN=false to apply"
  exit 0
fi

if [ "$total" -eq 0 ]; then
  jq -cn --arg repo "$REPOSITORY_NAME" '{repository: $repo, dry_run: false, deleted: 0, failures: []}' \
    > "$NUON_ACTIONS_OUTPUT_FILEPATH"
  echo "nothing to delete"
  exit 0
fi

deleted=0
failures="[]"

# batch-delete-image accepts at most 100 image ids per call.
for ((i = 0; i < total; i += 100)); do
  image_ids=()
  while IFS= read -r tag; do
    image_ids+=("imageTag=$tag")
  done < <(echo "$tags" | jq -r --argjson i "$i" '.[$i:($i + 100)][]')

  echo "deleting tags $((i + 1))-$((i + ${#image_ids[@]})) of $total"
  resp=$(aws ecr batch-delete-image \
    --repository-name "$REPOSITORY_NAME" \
    --region "$AWS_REGION" \
    --image-ids "${image_ids[@]}" \
    --output json)

  deleted=$((deleted + $(echo "$resp" | jq '.imageIds | length')))
  failures=$(jq -cn --argjson acc "$failures" --argjson new "$(echo "$resp" | jq '.failures')" '$acc + $new')
done

result=$(jq -cn \
  --arg repo "$REPOSITORY_NAME" \
  --argjson deleted "$deleted" \
  --argjson failures "$failures" \
  '{repository: $repo, dry_run: false, deleted: $deleted, failures: $failures}')
echo "$result" > "$NUON_ACTIONS_OUTPUT_FILEPATH"
echo "$result" | jq .

failed=$(echo "$failures" | jq 'length')
if [ "$failed" -gt 0 ]; then
  echo "completed with $failed failure(s)" >&2
  exit 1
fi

echo "deleted $deleted tag(s) from $REPOSITORY_NAME"
