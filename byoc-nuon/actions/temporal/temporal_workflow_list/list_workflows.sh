#!/usr/bin/env bash
set -e
set -o pipefail
set -u

kubectl config set-context --current --namespace=temporal >/dev/null

echo >&2 "fetching all workflows for namespace ${NAMESPACE}..."

raw=$(kubectl -n temporal exec -i deployment/temporal-admintools -- \
  temporal workflow list \
    --namespace "$NAMESPACE" \
    --query "ExecutionStatus='Running'" \
    --limit 0 \
    --output json 2>/dev/null)

total=$(echo "$raw" | jq 'length')
echo >&2 "found ${total} workflows in namespace ${NAMESPACE}"

# print in pages of 100
page=0
while [ $((page * 100)) -lt "$total" ]; do
  echo >&2 "--- page $((page + 1)) ---"
  echo "$raw" | jq -r --argjson offset $((page * 100)) '
    .[$offset:$offset+100][] |
    "workflow_id=\\(.execution.workflowId)  type=\\(.type.name)  status=\\(.status)  start=\\(.startTime)"
  '
  page=$((page + 1))
done

echo >&2 "done listing workflows in namespace ${NAMESPACE}"
