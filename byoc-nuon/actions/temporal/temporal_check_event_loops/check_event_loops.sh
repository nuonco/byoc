#!/usr/bin/env bash

set -e
set -o pipefail
set -u

EVENT_LOOP_QUERY="(WorkflowType='ActionEventLoop' OR WorkflowType='ComponentEventLoop' OR WorkflowType='SandboxEventLoop' OR WorkflowType='StackEventLoop' OR WorkflowType='EventLoop') AND ExecutionStatus='Running'"

trun() {
  kubectl -n temporal exec -i deployment/temporal-admintools -- "$@"
}

total=0
for ns in installs actions runners apps; do
  echo "=== $ns ==="
  count=$(trun temporal workflow count \
    --namespace "$ns" \
    --query "$EVENT_LOOP_QUERY" 2>/dev/null \
    | sed -n 's/.*Total: *\([0-9][0-9]*\).*/\1/p' | head -n1)
  count=${count:-0}
  echo "  $count running"
  total=$((total + count))
done

echo ""
echo "total: $total"
