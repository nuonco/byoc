#!/usr/bin/env bash

set -e
set -o pipefail
set -u

log_level="${LOG_LEVEL:-info}"
db_log_queries="${DB_LOG_QUERIES:-false}"

# internal
namespace="ctl-api"
deployment_name="ctl-api-startup"
state_configmap="ctl-api-startup-scale-state"

# ctl-api-startup runs the migration; ctl-api-init is the psql jump box.
keep_deployments="ctl-api-startup ctl-api-init"

drain_timeout="${DRAIN_TIMEOUT:-240}"

# scaling ctl-api to 0 takes the whole control plane down, so it is opt-in: the
# post-deploy action sets it, the manual action does not. leftover state from an aborted
# run is still restored either way.
scale_down_enabled="${SCALE_DOWN:-false}"

state_exists() {
  kubectl get configmap -n "$namespace" "$state_configmap" >/dev/null 2>&1
}

state_get() {
  kubectl get configmap -n "$namespace" "$state_configmap" -o json | jq -r --arg key "$1" '.data[$key]'
}

# save_state is write-once on purpose. a run that dies after scaling down leaves the
# configmap behind holding the real replica counts; re-saving here would record the
# scaled-down values (0) as the originals and lose them for good.
save_state() {
  if state_exists; then
    echo "[ctl_api startup] reusing scale state from a previous run"
    state_get deployments.json | jq -r '.[] | "  \(.name): \(.replicas)"'
    return 0
  fi

  local deployments hpas
  deployments=$(kubectl get deploy -n "$namespace" -o json | jq -c --arg keep "$keep_deployments" '
    ($keep | split(" ")) as $keep
    | [ .items[]
        | .metadata.name as $name
        | select(($keep | index($name)) | not)
        | { name: $name, replicas: (.spec.replicas // 0) } ]')

  # strip server-managed fields so the manifest re-applies cleanly, but keep the rest of
  # the annotations: helm ownership metadata lives there, and re-applying without it makes
  # the next chart deploy fail on invalid ownership. matches ctl_api_pause_worker_hpas.
  hpas=$(kubectl get hpa -n "$namespace" -o json | jq -c '
    { apiVersion: "v1", kind: "List",
      items: [ .items[]
        | del(.status, .metadata.resourceVersion, .metadata.uid,
              .metadata.creationTimestamp, .metadata.generation,
              .metadata.managedFields, .metadata.selfLink)
        | .metadata.annotations |= ((. // {})
            | with_entries(select(.key | startswith("kubectl.kubernetes.io") | not))) ] }')

  echo "[ctl_api startup] saving scale state"
  echo "$deployments" | jq -r '.[] | "  \(.name): \(.replicas)"'

  local tmpdir
  tmpdir=$(mktemp -d)
  printf '%s' "$deployments" > "$tmpdir/deployments.json"
  printf '%s' "$hpas" > "$tmpdir/hpas.json"
  kubectl create configmap -n "$namespace" "$state_configmap" \
    --from-file="$tmpdir/deployments.json" \
    --from-file="$tmpdir/hpas.json"
  rm -rf "$tmpdir"
}

scale_down() {
  local names_json hpa_names
  names_json=$(state_get deployments.json | jq -c '[ .[].name ]')

  # an hpa cannot have minReplicas=0 on EKS/GKE, so it has to be deleted outright or
  # it scales the deployment straight back up within ~15s.
  hpa_names=$(state_get hpas.json | jq -r --argjson names "$names_json" '
    .items[]
    | .spec.scaleTargetRef.name as $target
    | select($names | index($target))
    | .metadata.name')

  echo "[ctl_api startup] deleting hpas"
  for name in $hpa_names; do
    kubectl delete hpa -n "$namespace" "$name" --ignore-not-found
  done

  echo "[ctl_api startup] scaling deployments to 0"
  for name in $(echo "$names_json" | jq -r '.[]'); do
    kubectl scale -n "$namespace" --replicas=0 "deployment/$name"
  done

  echo "[ctl_api startup] waiting up to ${drain_timeout}s for pods to terminate"
  local deadline=$((SECONDS + drain_timeout))
  while :; do
    local pending
    pending=$(kubectl get deploy -n "$namespace" -o json | jq -r --argjson names "$names_json" '
      [ .items[]
        | .metadata.name as $name
        | select($names | index($name))
        | select((.status.replicas // 0) > 0)
        | "\($name)=\(.status.replicas)" ] | join(" ")')

    if [ -z "$pending" ]; then
      echo "[ctl_api startup] drained"
      return 0
    fi

    if [ "$SECONDS" -ge "$deadline" ]; then
      echo "[ctl_api startup] WARN: still running: $pending"
      echo "[ctl_api startup] WARN: migrating anyway, expect lock contention"
      return 0
    fi

    sleep 5
  done
}

# best effort throughout: a half-restored ctl-api is worse than a noisy log.
restore_state() {
  if ! state_exists; then
    return 0
  fi

  local deployments hpas
  deployments=$(state_get deployments.json)
  hpas=$(state_get hpas.json)

  # replicas first, then hpas: a native hpa will not scale a deployment up off 0 (no pods
  # means no metrics), so the deployments have to be seeded explicitly.
  echo "[ctl_api startup] restoring replicas"
  echo "$deployments" | jq -r '.[] | "\(.name) \(.replicas)"' | while read -r name replicas; do
    kubectl scale -n "$namespace" --replicas="$replicas" "deployment/$name" || true
  done

  if [ "$(echo "$hpas" | jq '.items | length')" -gt 0 ]; then
    echo "[ctl_api startup] restoring hpas"
    echo "$hpas" | kubectl apply -f - || true
  fi

  kubectl delete configmap -n "$namespace" "$state_configmap" --ignore-not-found
}

on_exit() {
  local rc="${1:-$?}"
  # drop every trap first: exit below would otherwise re-enter this via the EXIT trap.
  trap - EXIT INT TERM

  if [ -n "${migrate_pid:-}" ]; then
    kill "$migrate_pid" 2>/dev/null || true
  fi

  echo "[ctl_api startup] scaling ctl-api back up (exit=$rc)"
  restore_state || true
  kubectl scale -n "$namespace" --replicas=0 "deployment/$deployment_name" || true

  exit "$rc"
}

echo "[ctl_api startup] kubectl auth whoami"
kubectl auth whoami -o json | jq -c

trap on_exit EXIT
trap 'on_exit 143' INT TERM

echo "[ctl_api startup] scale up the deployment"
# NOTE(fd): this is only stricktly necessary when we run this action manually. during the normal
# course of a deployment, this action runs right after ctl-api which means this deployment will
# already be scaled up.
kubectl scale -n ctl-api --replicas=1 "deployment/$deployment_name"
kubectl wait deployment -n ctl-api $deployment_name --for condition=Available=True --timeout=90s

echo "[ctl_api startup] get a pod from the deployment"
pod=`kubectl -n ctl-api get pods --selector app.nuon.co/name="$deployment_name" -o json | jq -r '.items[0].metadata.name'`

# this pod sits on the public nodepool alongside the api deployments. scaling those to 0
# leaves the node underutilized, and karpenter consolidates it out from under the migration
# (consolidateAfter: 1m) - the pod is evicted and the migration dies with exit 137. the
# annotation blocks voluntary disruption of the node for as long as this pod exists.
echo "[ctl_api startup] protecting the pod from karpenter consolidation"
kubectl annotate pod -n "$namespace" "$pod" karpenter.sh/do-not-disrupt=true --overwrite

if [ "$scale_down_enabled" = "true" ]; then
  save_state
  scale_down
else
  echo "[ctl_api startup] SCALE_DOWN not enabled, migrating against live traffic"
fi

# backgrounded, then waited on: bash defers a trapped signal until the foreground child
# returns, so with the exec in the foreground a SIGTERM would not restore scale until the
# migration finished - long after the action has been killed.
echo "[ctl_api startup] preparing to initialize"
kubectl --namespace=ctl-api exec -i "$pod" -- \
  env "LOG_LEVEL=$log_level" "DB_LOG_QUERIES=$db_log_queries" \
  /bin/service startup &
migrate_pid=$!
wait "$migrate_pid"
