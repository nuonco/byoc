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
    echo "  [$ns] $running batch op(s) running, waiting 5s... (attempt $attempts)"
    sleep 5
  done
}

total_found=0

for ns in installs actions runners apps; do
  echo "--- $ns ---"

  count=$(trun temporal workflow count \
    --namespace "$ns" \
    --query "($EVENT_LOOP_QUERY) AND ExecutionStatus='Running'" 2>/dev/null \
    | sed -n 's/.*Total: *\([0-9][0-9]*\).*/\1/p' | head -n1)
  count=${count:-0}
  echo "  found $count EventLoop workflow(s)"
  total_found=$((total_found + count))

  if [[ "$count" -gt 0 ]]; then
    echo "  waiting for batch capacity..."
    wait_for_batch_capacity "$ns"
    echo "  submitting delete..."
    trun temporal workflow delete \
      --namespace "$ns" \
      --query "$EVENT_LOOP_QUERY" \
      --reason "$REASON" \
      --yes 2>&1 || true
    echo "  delete submitted"
  fi
done

echo ""
echo "total found: $total_found"
