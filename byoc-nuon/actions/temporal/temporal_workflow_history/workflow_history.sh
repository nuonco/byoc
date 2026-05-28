#!/usr/bin/env bash
set -e
set -o pipefail
set -u

kubectl config set-context --current --namespace=temporal >/dev/null

# describe the workflow (current run)
echo >&2 "describing workflow ${WORKFLOW_ID} in namespace ${NAMESPACE}..."
kubectl -n temporal exec -i deployment/temporal-admintools -- \
  temporal workflow describe \
    --namespace "$NAMESPACE" \
    --workflow-id "$WORKFLOW_ID" \
    --output json

# function: fetch full history for a single run
fetch_run_history() {
  local wf_id="$1"
  local run_id="$2"
  local run_events="[]"
  local next_token=""

  while true; do
    args=(
      temporal workflow show
      --namespace "$NAMESPACE"
      --workflow-id "$wf_id"
      --run-id "$run_id"
      --output json
      --max-field-length 0
    )
    if [ -n "$next_token" ]; then
      args+=(--next-page-token "$next_token")
    fi

    page=$(kubectl -n temporal exec -i deployment/temporal-admintools -- "${args[@]}")

    # debug: show first 500 chars of raw output
    echo >&2 "  raw output (first 500 chars): $(echo "$page" | head -c 500)"
    echo >&2 "  raw output lines: $(echo "$page" | wc -l)"

    # temporal workflow show --output json outputs one JSON event per line (ndjson)
    # slurp all lines into an array
    page_events=$(echo "$page" | jq -cs '[.[] | select(type == "object")]')

    count=$(echo "$page_events" | jq 'length')
    run_events=$(echo "$run_events" "$page_events" | jq -s '.[0] + .[1]')
    total=$(echo "$run_events" | jq 'length')
    echo >&2 "  fetched ${count} events (run total: ${total})"

    # ndjson format has no pagination token, fetch is complete in one call
    break
  done

  echo "$run_events"
}

# resolve firstRunId and fetch its full history
echo >&2 "resolving first run for workflow ${WORKFLOW_ID}..."
describe=$(kubectl -n temporal exec -i deployment/temporal-admintools -- \
  temporal workflow describe \
    --namespace "$NAMESPACE" \
    --workflow-id "$WORKFLOW_ID" \
    --output json 2>/dev/null)

first_run_id=$(echo "$describe" | jq -r '.workflowExecutionInfo.firstRunId // empty')
current_run_id=$(echo "$describe" | jq -r '.workflowExecutionInfo.execution.runId // empty')

if [ -z "$first_run_id" ]; then
  first_run_id="$current_run_id"
fi

echo >&2 "first run: ${first_run_id} (current: ${current_run_id})"
echo >&2 "fetching history for first run..."
run_events=$(fetch_run_history "$WORKFLOW_ID" "$first_run_id")
run_count=$(echo "$run_events" | jq 'length')
echo >&2 "done: ${run_count} events"

jq -cn --arg rid "$first_run_id" --arg crid "$current_run_id" --argjson events "$run_events" --argjson count "$run_count" \
  '{ first_run_id: $rid, current_run_id: $crid, is_same_run: ($rid == $crid), event_count: $count, events: $events }'
