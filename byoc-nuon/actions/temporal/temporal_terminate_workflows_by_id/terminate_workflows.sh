#!/usr/bin/env bash
set -e
set -o pipefail
set -u

kubectl config set-context --current --namespace=temporal >/dev/null

if [ -z "${WORKFLOW_IDS:-}" ]; then
  echo >&2 "WORKFLOW_IDS is empty, nothing to terminate"
  exit 1
fi

# split comma-separated WORKFLOW_IDS into an array, trimming whitespace
IFS=',' read -ra ids <<< "$WORKFLOW_IDS"

total=${#ids[@]}
echo >&2 "terminating ${total} workflow(s) in namespace ${NAMESPACE}..."

ok=0
fail=0
for raw_id in "${ids[@]}"; do
  # trim leading/trailing whitespace
  wf_id="$(echo "$raw_id" | xargs)"
  [ -z "$wf_id" ] && continue

  echo >&2 "terminating workflow ${wf_id}..."
  if kubectl -n temporal exec -i deployment/temporal-admintools -- \
      temporal workflow terminate \
        --namespace "$NAMESPACE" \
        --workflow-id "$wf_id" \
        --reason "$REASON"; then
    echo "terminated workflow_id=${wf_id} namespace=${NAMESPACE}"
    ok=$((ok + 1))
  else
    echo >&2 "failed to terminate workflow_id=${wf_id} namespace=${NAMESPACE}"
    fail=$((fail + 1))
  fi
done

echo >&2 "done: ${ok} terminated, ${fail} failed (of ${total})"

# exit non-zero if any termination failed
[ "$fail" -eq 0 ]
