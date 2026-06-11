#!/usr/bin/env bash
set -e
set -o pipefail
set -u

kubectl config set-context --current --namespace=temporal >/dev/null

echo >&2 "describing workflow ${WORKFLOW_ID} in namespace ${NAMESPACE}..."
describe=$(kubectl -n temporal exec -i deployment/temporal-admintools -- \
  temporal workflow describe \
    --namespace "$NAMESPACE" \
    --workflow-id "$WORKFLOW_ID" \
    --output json)

first_run_id=$(echo "$describe" | jq -r '.workflowExecutionInfo.firstRunId // empty')
current_run_id=$(echo "$describe" | jq -r '.workflowExecutionInfo.execution.runId // empty')
if [ -z "$current_run_id" ]; then
  current_run_id="$first_run_id"
fi

echo >&2 "first run: ${first_run_id} (current: ${current_run_id})"
echo >&2 "fetching history for current run..."

raw_events=$(kubectl -n temporal exec -i deployment/temporal-admintools -- \
  temporal workflow show \
    --namespace "$NAMESPACE" \
    --workflow-id "$WORKFLOW_ID" \
    --run-id "$current_run_id" \
    --output json \
    --max-field-length 0)

# ndjson — one event per line
events_json=$(echo "$raw_events" | jq -cs '[.[] | select(type == "object")]')
event_count=$(echo "$events_json" | jq 'length')
echo >&2 "done: ${event_count} events"

# Extract input from the first WorkflowExecutionStarted event.
# Temporal encodes payload data as base64 JSON.
input_json=$(echo "$events_json" | jq -r '
  [.[] | select(.eventType == "EVENT_TYPE_WORKFLOW_EXECUTION_STARTED")][0]
  | .workflowExecutionStartedEventAttributes.input.payloads // []
  | map(.data // "" | @base64d) | join("")
' 2>/dev/null || echo "")

# Extract result from the closing event, if any.
result_json=$(echo "$events_json" | jq -r '
  [.[] | select(.eventType | test("WORKFLOW_EXECUTION_(COMPLETED|FAILED|CANCELED|TERMINATED|TIMED_OUT)"))][-1]
  | (.workflowExecutionCompletedEventAttributes.result.payloads // [])
  | map(.data // "" | @base64d) | join("")
' 2>/dev/null || echo "")

# Build a compact event summary (id, time, type, optional details)
event_summary=$(echo "$events_json" | jq -c '[.[] | {
  event_id:   .eventId,
  event_time: .eventTime,
  event_type: (.eventType // "" | sub("EVENT_TYPE_"; ""))
}]')

info=$(echo "$describe" | jq -c '{
  workflow_id:            .workflowExecutionInfo.execution.workflowId,
  run_id:                 .workflowExecutionInfo.execution.runId,
  first_run_id:           .workflowExecutionInfo.firstRunId,
  type:                   .workflowExecutionInfo.type.name,
  status:                 .workflowExecutionInfo.status,
  task_queue:             (.executionConfig.taskQueue.name // .workflowExecutionInfo.taskQueue),
  start_time:             .workflowExecutionInfo.startTime,
  close_time:             .workflowExecutionInfo.closeTime,
  execution_time:         .workflowExecutionInfo.executionTime,
  history_length:         .workflowExecutionInfo.historyLength,
  history_size_bytes:     .workflowExecutionInfo.historySizeBytes,
  state_transition_count: .workflowExecutionInfo.stateTransitionCount,
  parent_workflow_id:     .workflowExecutionInfo.parentExecution.workflowId,
  parent_run_id:          .workflowExecutionInfo.parentExecution.runId
}')

outputs=$(jq -cn \
  --argjson info "$info" \
  --arg namespace "$NAMESPACE" \
  --arg input "$input_json" \
  --arg result "$result_json" \
  --argjson event_count "$event_count" \
  --argjson events "$event_summary" \
  --arg updated_at "$(TZ=UTC date +%Y-%m-%dT%H:%M:%SZ)" \
  '$info + {
    namespace:   $namespace,
    input:       $input,
    result:      $result,
    event_count: $event_count,
    events:      $events,
    updated_at:  $updated_at
  }')

# Human-readable summary on stdout
echo "$outputs" | jq '.'

if [[ -n "${NUON_ACTIONS_OUTPUT_FILEPATH:-}" ]]; then
  echo >&2 "writing outputs to $NUON_ACTIONS_OUTPUT_FILEPATH"
  echo "$outputs" > "$NUON_ACTIONS_OUTPUT_FILEPATH"
fi
