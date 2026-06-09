#!/usr/bin/env bash
#
# List the N most recent Temporal workflows in a namespace, newest first,
# summarizing workflow id, type, status, and start/close times.
#
# Env vars:
#   NAMESPACE (optional) Temporal namespace; defaults to "general"
#   LIMIT     (optional) max workflows to return; defaults to 10

set -e
set -o pipefail
set -u

namespace="${NAMESPACE:-general}"
limit="${LIMIT:-10}"

if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
  echo "[list latest] ERROR: LIMIT must be an integer, got: $limit" >&2
  exit 1
fi

kubectl config set-context --current --namespace=temporal >/dev/null

echo >&2 "[list latest] fetching ${limit} most recent workflows in namespace ${namespace}..."

# `temporal workflow list` returns results newest-first by default; --limit
# caps the count. (ORDER BY is unsupported on standard visibility stores.)
raw=$(kubectl -n temporal exec -i deployment/temporal-admintools -- \
  temporal workflow list \
    --namespace "$namespace" \
    --limit "$limit" \
    --output json 2>/dev/null)

# temporal workflow list --output json emits a JSON array of executions.
summary=$(echo "$raw" | jq '[ .[] | {
  workflow_id: .execution.workflowId,
  run_id:      .execution.runId,
  type:        .type.name,
  status:      (.status | sub("^WORKFLOW_EXECUTION_STATUS_"; "")),
  start_time:  .startTime,
  close_time:  (.closeTime // null),
  task_queue:  (.taskQueue // null)
} ]')

count=$(echo "$summary" | jq 'length')
echo >&2 "[list latest] found ${count} workflows"

# human-readable table to the logs
echo "$summary" | jq -r '.[] |
  "status=\(.status)  type=\(.type)  start=\(.start_time)  id=\(.workflow_id)"'

if [[ -n "${NUON_ACTIONS_OUTPUT_FILEPATH:-}" ]]; then
  echo >&2 "[list latest] writing outputs"
  jq -cn --arg ns "$namespace" --argjson n "$count" --argjson wfs "$summary" \
    '{namespace: $ns, count: $n, workflows: $wfs}' > "$NUON_ACTIONS_OUTPUT_FILEPATH"
fi

echo >&2 "[list latest] done"
