#!/usr/bin/env bash

set -e
set -o pipefail
set -u

# Removes one or more resources (or whole modules) from a component's Terraform
# state WITHOUT destroying them, by driving the Terraform CLI against the Nuon
# HTTP state backend. Used as a teardown step: after a critical resource has been
# deleted out-of-band via the cloud API, its address is still in Terraform state,
# so a normal teardown plan would try to destroy it and be blocked (by the
# block-destructive-changes policy and/or a lifecycle prevent_destroy). Detaching
# it here lets the remaining (non-critical) resources tear down cleanly.
#
# Required env:
#   STATE_ADDRESSES       space/comma-separated Terraform addresses to remove.
#                         May be individual resources (google_storage_bucket.blob)
#                         or whole modules (module.foo).
#   plus ONE workspace selector (see below).
#
# Workspace selector (pick one; precedence is top-to-bottom):
#   WORKSPACE_ID          explicit terraform workspace id (e.g. tfw...). Skips the
#                         lookup entirely — use the id from the "Use Terraform CLI"
#                         modal when you already have it.
#   WORKSPACE_OWNER_TYPE  match the workspace by owner_type. Use this to target the
#                         sandbox: owner_type "install_sandbox_run". The runner's
#                         workspace list is install-scoped, so there is exactly one
#                         sandbox workspace. (Components are "install_deploy".)
#   INSTALL_COMPONENT_ID  match the workspace by owner_id == this id — i.e. a
#                         component's workspace (owner_type "install_deploy"). What
#                         the cloudsql_state_rm / gcs_state_rm actions use.
# Optional env:
#   WORKSPACE_OWNER_ID    explicit owner_id to match (defaults to INSTALL_COMPONENT_ID).
#   TF_VERSION            terraform version to use (default 1.11.3, match component)
#   LABEL / DB_LABEL      human-friendly label for log output
#
# Endpoint is read from the standard action environment (RUNNER_API_URL). The
# runner API token is not exported into the action env, so we mint one the same
# way the runner host does — `runner mng fetch-token` (cloud instance identity).
#
# NOTE: this drives the Terraform CLI against the Nuon runner HTTP state backend
# using the backend's ?token= query-param auth. It is the interim mechanism
# until a first-class "terraform state rm" runbook step exists. This script is
# cloud-agnostic (it never calls a cloud provider CLI) and is shared verbatim
# with the AWS app config.

tf_version="${TF_VERSION:-1.11.3}"
label="${LABEL:-${DB_LABEL:-component}}"

echo "==================================================================="
echo " Terraform state rm: ${label}"
echo "==================================================================="

# ── preflight ──────────────────────────────────────────────────────────────
: "${RUNNER_API_URL:?RUNNER_API_URL not present in environment}"
: "${STATE_ADDRESSES:?STATE_ADDRESSES is required}"

# resolve the owner_id to match (explicit WORKSPACE_OWNER_ID, else the component id)
match_owner_id="${WORKSPACE_OWNER_ID:-${INSTALL_COMPONENT_ID:-}}"
match_owner_type="${WORKSPACE_OWNER_TYPE:-}"
if [ -z "${WORKSPACE_ID:-}" ] && [ -z "$match_owner_id" ] && [ -z "$match_owner_type" ]; then
  echo "ERROR: provide a workspace selector: WORKSPACE_ID, WORKSPACE_OWNER_TYPE, or INSTALL_COMPONENT_ID." >&2
  exit 1
fi

# normalize address separators to whitespace
addresses=$(echo "$STATE_ADDRESSES" | tr ',' ' ')

# ── mint a runner API token via instance identity ────────────────────────────
# The runner fetches its token via cloud instance-identity and keeps it in
# memory (not in the container env), so we re-mint one the same way the host
# bootstrap does. fetch-token reads RUNNER_API_URL / RUNNER_AUTH_METHOD /
# RUNNER_ID from the environment.
if [ -z "${RUNNER_API_TOKEN:-}" ]; then
  if ! command -v runner >/dev/null 2>&1; then
    echo "ERROR: RUNNER_API_TOKEN not set and 'runner' binary not found to mint one." >&2
    exit 1
  fi
  echo "Minting a runner API token via instance identity..."
  token_json=$(runner mng fetch-token --json)
  if command -v jq >/dev/null 2>&1; then
    RUNNER_API_TOKEN=$(printf '%s' "$token_json" | jq -r '.token // empty')
  elif command -v python3 >/dev/null 2>&1; then
    RUNNER_API_TOKEN=$(printf '%s' "$token_json" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("token",""))')
  else
    echo "ERROR: need jq or python3 to parse the fetch-token response." >&2
    exit 1
  fi
fi

if [ -z "${RUNNER_API_TOKEN:-}" ] || [ "$RUNNER_API_TOKEN" = "null" ]; then
  echo "ERROR: failed to obtain a runner API token." >&2
  exit 1
fi

# ── resolve the terraform workspace id ───────────────────────────────────────
# Precedence: explicit WORKSPACE_ID > match by owner_type / owner_id in the list.
if [ -n "${WORKSPACE_ID:-}" ]; then
  workspace_id="$WORKSPACE_ID"
  echo "Using explicit workspace id: ${workspace_id}"
else
  echo "Looking up terraform workspace (owner_id='${match_owner_id:-<any>}' owner_type='${match_owner_type:-<any>}')..."
  ws_json=$(curl -fsS -H "Authorization: Bearer ${RUNNER_API_TOKEN}" \
    "${RUNNER_API_URL}/v1/terraform-workspaces")

  if command -v jq >/dev/null 2>&1; then
    workspace_id=$(printf '%s' "$ws_json" \
      | jq -r --arg oid "$match_owner_id" --arg otype "$match_owner_type" \
        '.[] | select(($oid=="" or .owner_id==$oid) and ($otype=="" or .owner_type==$otype)) | .id' \
      | head -n1)
  elif command -v python3 >/dev/null 2>&1; then
    workspace_id=$(printf '%s' "$ws_json" | MATCH_OID="$match_owner_id" MATCH_OTYPE="$match_owner_type" python3 -c '
import sys, json, os
oid = os.environ.get("MATCH_OID", "")
otype = os.environ.get("MATCH_OTYPE", "")
ws = json.load(sys.stdin)
print(next((w["id"] for w in ws
            if (oid == "" or w.get("owner_id") == oid)
            and (otype == "" or w.get("owner_type") == otype)), ""))')
  else
    echo "ERROR: need jq or python3 to parse the workspace list." >&2
    exit 1
  fi

  if [ -z "${workspace_id:-}" ] || [ "$workspace_id" = "null" ]; then
    echo "ERROR: no terraform workspace found matching owner_id='${match_owner_id}' owner_type='${match_owner_type}'." >&2
    exit 1
  fi
fi
echo "Workspace: ${workspace_id}"

# ── ensure a terraform binary is available ───────────────────────────────────
workdir="$(pwd)/.tf_state_rm"
mkdir -p "$workdir"

if command -v terraform >/dev/null 2>&1; then
  tf=terraform
else
  echo "terraform not on PATH — downloading ${tf_version}..."
  os="linux"
  arch="$(uname -m)"
  case "$arch" in
    x86_64) arch="amd64" ;;
    aarch64 | arm64) arch="arm64" ;;
    *) echo "ERROR: unsupported arch ${arch}" >&2; exit 1 ;;
  esac
  url="https://releases.hashicorp.com/terraform/${tf_version}/terraform_${tf_version}_${os}_${arch}.zip"
  curl -fsSL "$url" -o "$workdir/terraform.zip"
  unzip -oq "$workdir/terraform.zip" -d "$workdir"
  tf="$workdir/terraform"
fi

# ── init a backend-only workspace (no module/provider code needed for state rm) ─
cat > "$workdir/backend.tf" <<'EOF'
terraform {
  backend "http" {}
}
EOF

addr="${RUNNER_API_URL}/v1/terraform-backend?workspace_id=${workspace_id}&token=${RUNNER_API_TOKEN}"
lock="${RUNNER_API_URL}/v1/terraform-workspaces/${workspace_id}/lock?token=${RUNNER_API_TOKEN}"
unlock="${RUNNER_API_URL}/v1/terraform-workspaces/${workspace_id}/unlock?token=${RUNNER_API_TOKEN}"

echo "Initializing http backend..."
(
  cd "$workdir"
  "$tf" init -reconfigure -input=false \
    -backend-config="address=${addr}" \
    -backend-config="lock_address=${lock}" \
    -backend-config="lock_method=POST" \
    -backend-config="unlock_address=${unlock}" \
    -backend-config="unlock_method=POST" >/dev/null
)

# ── remove each requested address (idempotent: tolerate already-absent) ──────
# Works for individual resources AND whole modules (module.<name>). We attempt
# the rm and treat "no matching" as a no-op so re-runs and partial state are safe.
for addr_to_rm in $addresses; do
  if out=$(cd "$workdir" && "$tf" state rm "$addr_to_rm" 2>&1); then
    echo "Removed from state: ${addr_to_rm}"
  else
    case "$out" in
      *"No matching"* | *"no matching"* | *"not found"* | *"No instance"*)
        echo "Not in state (already removed?), skipping: ${addr_to_rm}" ;;
      *)
        echo "$out" >&2
        exit 1 ;;
    esac
  fi
done

echo ""
echo "State detach complete for ${label}."
