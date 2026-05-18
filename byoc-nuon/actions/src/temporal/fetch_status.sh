#!/usr/bin/env bash
#
# Lists active Temporal workflows per namespace and writes a trimmed
# JSON summary to the action outputs. Consumed by the "Temporal Status"
# section in README.md.

set -e
set -o pipefail
set -u

# Namespaces mirror temporalWorkerNamespaces in ctl-api:
# internal/app/admin-dashboard/service/temporal_workers.go.
namespaces=(
  general
  installs
  runners
  orgs
  components
  apps
  actions
  vcs
  onboardings
)

kubectl config set-context --current --namespace=temporal >/dev/null
pod=$(kubectl get pods -l app.kubernetes.io/component=admintools \
  -o custom-columns=NAME:.metadata.name --no-headers | head -n1)

list_workflows() {
  local ns="$1"
  kubectl exec -i "$pod" -- temporal workflow list \
    --namespace "$ns" \
    --query "ExecutionStatus='Running'" \
    --limit 0 \
    --output json
}

# The runner parses outputs line-by-line (bufio.Scanner, ~64 KB per line) and
# merges all lines into one map. Emit small JSON objects, one per line:
# - {"generated_at": "..."}
# - {"namespace_names": [...]}
# - per namespace: {"ns_<n>_count": N} plus N chunks {"ns_<n>_chunk_<i>": [...wfs...]}
# Chunking keeps any single line well under the scanner limit even when a
# namespace has thousands of running workflows.

chunk_size=100

generated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
jq -cn --arg t "$generated_at" '{ generated_at: $t }' \
  >> "$NUON_ACTIONS_OUTPUT_FILEPATH"

printf '%s\n' "${namespaces[@]}" \
  | jq -cR --slurp 'split("\n") | map(select(length > 0)) | { namespace_names: . }' \
  >> "$NUON_ACTIONS_OUTPUT_FILEPATH"

for ns in "${namespaces[@]}"; do
  echo >&2 "listing workflows for namespace=${ns}..."
  raw=$(list_workflows "$ns" 2>/dev/null || echo '[]')

  trimmed=$(echo "$raw" | jq -c '
    map({
      workflow_id:   .execution.workflowId,
      workflow_type: .type.name,
      start_time:    .startTime,
    })
  ')

  total=$(echo "$trimmed" | jq 'length')
  chunks=$(( (total + chunk_size - 1) / chunk_size ))
  [ "$chunks" -eq 0 ] && chunks=0

  jq -cn --arg ns "$ns" --argjson c "$chunks" \
    '{ ("ns_" + $ns + "_count"): $c }' \
    >> "$NUON_ACTIONS_OUTPUT_FILEPATH"

  i=0
  while [ "$i" -lt "$chunks" ]; do
    echo "$trimmed" | jq -c --arg ns "$ns" --argjson i "$i" --argjson cs "$chunk_size" '
      { ("ns_" + $ns + "_chunk_" + ($i | tostring)): .[($i * $cs):(($i + 1) * $cs)] }
    ' >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
    i=$((i + 1))
  done
done
echo >&2 "wrote temporal status outputs"
