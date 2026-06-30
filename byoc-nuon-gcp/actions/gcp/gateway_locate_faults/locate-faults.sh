#!/usr/bin/env bash

# Locates HTTP fault injection ("fault filter abort") configured in the cluster.
# A fault can live in any of three places, so it checks all of them. Read-only;
# kubectl only, no cloud role.
#
# Prints a human-readable report to logs AND writes a structured result to
# NUON_ACTIONS_OUTPUT_FILEPATH ({"faults":[{kind,ns,name,detail}, ...]}) so the
# runbook README can render it.

set -u

faults='[]'
add_fault() {
  faults=$(printf '%s' "$faults" | jq -c \
    --arg k "$1" --arg ns "$2" --arg n "$3" --arg d "$4" \
    '. + [{kind:$k, ns:$ns, name:$n, detail:$d}]')
}

echo "==================================================================="
echo " Searching for HTTP fault injection in the cluster"
echo "==================================================================="

echo ""
echo "--- 1. Istio VirtualServices with a fault stanza ---"
if kubectl get virtualservice -A >/dev/null 2>&1; then
  vs_json=$(kubectl get virtualservice -A -o json 2>/dev/null)
  hits=$(printf '%s' "$vs_json" | jq -c '.items[] | select([.spec.http[]?.fault] | length > 0) | {ns:.metadata.namespace, name:.metadata.name, fault:(.spec.http[].fault)}')
  if [ -n "$hits" ]; then
    printf '%s\n' "$hits" | while IFS= read -r h; do
      ns=$(printf '%s' "$h" | jq -r '.ns'); name=$(printf '%s' "$h" | jq -r '.name'); det=$(printf '%s' "$h" | jq -c '.fault')
      echo "  ${ns}/${name}: ${det}"
    done
    # accumulate (subshell-safe: re-iterate)
    while IFS= read -r h; do
      [ -n "$h" ] || continue
      add_fault "VirtualService" "$(printf '%s' "$h" | jq -r '.ns')" "$(printf '%s' "$h" | jq -r '.name')" "$(printf '%s' "$h" | jq -c '.fault')"
    done <<EOF
$hits
EOF
  else
    echo "  none"
  fi
else
  echo "  (no VirtualService CRD — Istio not installed)"
fi

echo ""
echo "--- 2. EnvoyFilters that reference a fault filter ---"
if kubectl get envoyfilter -A >/dev/null 2>&1; then
  ef_json=$(kubectl get envoyfilter -A -o json 2>/dev/null)
  ef_hits=$(printf '%s' "$ef_json" | jq -c '.items[] | select((.. | strings? | test("fault"; "i")) // false) | {ns:.metadata.namespace, name:.metadata.name}' 2>/dev/null | sort -u)
  if [ -n "$ef_hits" ]; then
    while IFS= read -r h; do
      [ -n "$h" ] || continue
      ns=$(printf '%s' "$h" | jq -r '.ns'); name=$(printf '%s' "$h" | jq -r '.name')
      echo "  ${ns}/${name} (references 'fault')"
      add_fault "EnvoyFilter" "$ns" "$name" "references 'fault'"
    done <<EOF
$ef_hits
EOF
  else
    echo "  none reference 'fault'"
  fi
else
  echo "  (no EnvoyFilter CRD)"
fi

echo ""
echo "--- 3. Gateway API HTTPRoute filters ---"
kubectl get httproute -A -o json 2>/dev/null \
  | jq -r '.items[] | select([.spec.rules[]?.filters[]?] | length > 0) | "  \(.metadata.namespace)/\(.metadata.name): filters=[\([.spec.rules[]?.filters[]?.type] | join(", "))]"' \
  || true
echo "  (routes with no filters omitted)"

echo ""
echo "Fix: remove the fault stanza (or set its percentage to 0) on whatever is"
echo "listed above. This config is NOT in the byoc-nuon-gcp app config — it comes"
echo "from the sandbox/gateway layer or was applied out-of-band."

count=$(printf '%s' "$faults" | jq 'length')
printf '%s' "$faults" | jq -c '{faults: ., fault_count: length}' >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
echo ""
echo "(${count} fault definition(s) recorded to outputs)"
