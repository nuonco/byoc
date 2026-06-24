#!/usr/bin/env bash

set -e
set -o pipefail
set -u

REASON="${REASON:-event-loop cleanup}"
EVENT_LOOP_QUERY="WorkflowType='ActionEventLoop' OR WorkflowType='ComponentEventLoop' OR WorkflowType='SandboxEventLoop' OR WorkflowType='StackEventLoop' OR WorkflowType='EventLoop'"

trun() {
  kubectl -n temporal exec -i deployment/temporal-admintools -- "$@"
}

wait_for_batch_capacity() {
  local ns="$1"
  local attempts=0
  while true; do
    local running
    running=$(trun temporal batch list --namespace "$ns" 2>/dev/null | grep -c "Running" || true)
    if [[ "$running" -eq 0 ]]; then
      return
    fi
    attempts=$((attempts + 1))
    echo >&2 "  [$ns] $running batch op(s) running, waiting 5s... (attempt $attempts)"
    sleep 5
  done
}

echo >&2 "checking for EventLoop workflows..."

results="[]"
total_found=0

for ns in installs actions runners apps; do
  echo >&2 "--- checking namespace: $ns ---"

  count=$(trun temporal workflow count \
    --namespace "$ns" \
    --query "($EVENT_LOOP_QUERY) AND ExecutionStatus='Running'" 2>/dev/null \
    | sed -n 's/.*Total: *\([0-9][0-9]*\).*/\1/p' | head -n1)
  count=${count:-0}
  echo >&2 "  found $count EventLoop workflow(s) in $ns"
  total_found=$((total_found + count))

  deleted=false
  if [[ "$count" -gt 0 ]]; then
    echo >&2 "  waiting for batch capacity in $ns..."
    wait_for_batch_capacity "$ns"
    echo >&2 "  submitting delete for $ns..."
    trun temporal workflow delete \
      --namespace "$ns" \
      --query "$EVENT_LOOP_QUERY" \
      --reason "$REASON" \
      --yes 2>&1 || true
    deleted=true
    echo >&2 "  delete submitted for $ns"
  fi

  results=$(echo "$results" | jq -c \
    --arg ns "$ns" \
    --argjson found "$count" \
    --argjson deleted "$deleted" \
    '. + [{"name": $ns, "found": $found, "deleted": $deleted}]')
done

echo >&2 "done. total EventLoop workflows found: $total_found"

if [[ -n "${NUON_ACTIONS_OUTPUT_FILEPATH:-}" ]]; then
  echo >&2 "writing outputs to $NUON_ACTIONS_OUTPUT_FILEPATH"
  jq -nc \
    --argjson results "$results" \
    --argjson total_found "$total_found" \
    --argjson any_found "$( [[ $total_found -gt 0 ]] && echo true || echo false )" \
    --arg checked_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      checked_at: $checked_at,
      total_found: $total_found,
      any_found: $any_found,
      namespaces: $results
    }' > "$NUON_ACTIONS_OUTPUT_FILEPATH"
fi
