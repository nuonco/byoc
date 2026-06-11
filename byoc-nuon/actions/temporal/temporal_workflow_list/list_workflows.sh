#!/usr/bin/env bash
set -e
set -o pipefail
set -u

limit="${LIMIT:-10}"

if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
  echo >&2 "ERROR: LIMIT must be an integer, got: $limit"
  exit 1
fi

kubectl config set-context --current --namespace=temporal >/dev/null

echo >&2 "discovering temporal namespaces..."
namespaces_json=$(kubectl -n temporal exec -i deployment/temporal-admintools -- \
  temporal operator namespace list --output json 2>/dev/null)

excluded_namespaces='emitters installers onboardings releases temporal-system'
namespaces=$(echo "$namespaces_json" \
  | jq -r --arg excluded "$excluded_namespaces" '
      ($excluded | split(" ")) as $skip |
      .[].namespaceInfo.name
      | select(. as $n | $skip | index($n) | not)
    ' \
  | sort -u)
if [[ -z "$namespaces" ]]; then
  echo >&2 "ERROR: no temporal namespaces found"
  exit 1
fi
echo >&2 "found namespaces: $(echo "$namespaces" | paste -sd, -)"

grouped="[]"
total=0
for ns in $namespaces; do
  echo >&2 "--- fetching up to ${limit} most recent workflows for namespace ${ns} ---"
  raw=$(kubectl -n temporal exec -i deployment/temporal-admintools -- \
    temporal workflow list \
      --namespace "$ns" \
      --query "ExecutionStatus='Running'" \
      --limit "$limit" \
      --output json 2>/dev/null)

  count=$(echo "$raw" | jq 'length')

  count_out=$(kubectl -n temporal exec -i deployment/temporal-admintools -- \
    temporal workflow count \
      --namespace "$ns" \
      --query "ExecutionStatus='Running'" 2>/dev/null || true)
  running_total=$(echo "$count_out" | sed -n 's/.*Total: *\([0-9][0-9]*\).*/\1/p' | head -n1)
  running_total=${running_total:-0}

  total=$((total + count))
  echo >&2 "  returned ${count} workflows (running total in namespace: ${running_total})"

  echo "$raw" | jq -r --arg ns "$ns" '
    .[] |
    "namespace=\($ns)  workflow_id=\(.execution.workflowId)  type=\(.type.name)  start=\(.startTime)"
  '

  ns_entry=$(echo "$raw" | jq -c --arg ns "$ns" --argjson running_total "$running_total" '{
    name: $ns,
    workflow_count: length,
    running_total: $running_total,
    workflows: [.[] | {
      workflow_id: .execution.workflowId,
      run_id:      .execution.runId,
      type:        .type.name,
      start_time:  .startTime,
      close_time:  .closeTime,
      task_queue:  .taskQueue
    }]
  }')
  grouped=$(echo "$grouped $ns_entry" | jq -cs '.[0] + [.[1]]')
done

if [[ -n "${NUON_ACTIONS_OUTPUT_FILEPATH:-}" ]]; then
  echo >&2 "writing outputs to $NUON_ACTIONS_OUTPUT_FILEPATH"
  echo "$grouped" | jq -c \
    --argjson total "$total" \
    --arg updated_at "$(TZ=UTC date +%Y-%m-%dT%H:%M:%SZ)" \
    '{namespaces: ., total_count: $total, updated_at: $updated_at}' \
    > "$NUON_ACTIONS_OUTPUT_FILEPATH"
fi

echo >&2 "done listing workflows"
