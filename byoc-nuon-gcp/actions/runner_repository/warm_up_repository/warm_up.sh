#!/usr/bin/env bash
#
# warm-up-repository
#
# Warms up the install's Artifact Registry runner repository by importing every
# runner image version currently in use across the install's runners.
#
# Discovers the set of versions by querying ClickHouse for the distinct `version`
# values reported by runner heartbeats, then imports each tag from the upstream
# Nuon registry (SOURCE_IMAGE_URL) into the install's runner repository
# (RUNNER_REPOSITORY_URI). This is gar_runner_import fanned out over every
# active version instead of just the ctl-api configmap tag.
#
# Env:
#   RUNNER_REPOSITORY_URI  - destination Artifact Registry repo URI (this install)
#   OVERRIDE               - "true" to overwrite tags that already exist in the
#                            destination; "false" (default) to skip them.
set -euo pipefail

SOURCE_IMAGE_URL="public.ecr.aws/p7e3r5y0/runner"
: "${RUNNER_REPOSITORY_URI:?RUNNER_REPOSITORY_URI is required}"
OVERRIDE="${OVERRIDE:-false}"

CH_NS="clickhouse"
# Resolved by label rather than hardcoded ordinal: the operator renames pods when
# the shard/replica layout changes, and ch_verify_storage.sh already discovers it
# this way.
CH_POD=$(kubectl -n "$CH_NS" get pods -l clickhouse.altinity.com/chi=clickhouse-installation \
  -o jsonpath='{.items[0].metadata.name}')
if [ -z "$CH_POD" ]; then
  echo "warm-up-repository: no clickhouse pod found in namespace $CH_NS" >&2
  exit 1
fi

# latest_runner_heart_beats_view_v1 is the read target ctl-api itself uses. The
# underlying table was renamed to _v2 when heartbeats moved to a Replicated engine,
# so querying the pre-rename name returns UNKNOWN_TABLE.
#
# Single bare statement -- no trailing ';', WHERE, or FORMAT. clickhouse-client
# -q already emits TabSeparated (one value per line) for a non-interactive query,
# and empty/blank versions are filtered out in the import loop below.
CH_QUERY="SELECT DISTINCT version FROM ctl_api.latest_runner_heart_beats_view_v1"

echo "warm-up-repository: querying ClickHouse for distinct runner versions"
versions=$(kubectl exec -n "$CH_NS" "$CH_POD" -- \
  clickhouse client -d ctl_api -q "$CH_QUERY")

if [ -z "$versions" ]; then
  echo "warm-up-repository: no versions found in runner heartbeats; nothing to do" >&2
  exit 0
fi

echo "warm-up-repository: discovered versions:"
echo "$versions" | sed 's/^/  - /'

if ! command -v oras >/dev/null 2>&1; then
  echo "warm-up-repository: oras not found on PATH; expected to be bundled in the runner image" >&2
  exit 1
fi
oras_bin=$(command -v oras)

# Destination only -- see gar_runner_import/import.sh for why the upstream needs
# no login and why no impersonation flag is passed.
gar_host="${RUNNER_REPOSITORY_URI%%/*}"
echo "warm-up-repository: authenticating to $gar_host"
gcloud auth print-access-token \
  | "$oras_bin" login -u oauth2accesstoken --password-stdin "$gar_host"

src="${SOURCE_IMAGE_URL%/}"
dst="${RUNNER_REPOSITORY_URI%/}"

overall_status="ok"

while IFS= read -r version; do
  tag="${version// /}"
  [ -z "$tag" ] && continue

  status="copied"

  # If OVERRIDE is not enabled, skip when the tag already exists in the destination.
  if [ "$OVERRIDE" != "true" ]; then
    if "$oras_bin" manifest fetch --descriptor "${dst}:${tag}" >/dev/null 2>&1; then
      echo "warm-up-repository: ${dst}:${tag} already exists; skipping (set OVERRIDE=true to overwrite)"
      status="skipped"
    fi
  fi

  if [ "$status" = "copied" ]; then
    echo "warm-up-repository: copying ${src}:${tag} -> ${dst}:${tag}"
    if ! "$oras_bin" copy "${src}:${tag}" "${dst}:${tag}"; then
      echo "warm-up-repository: failed to copy tag ${tag}" >&2
      status="failed"
      overall_status="failed"
    fi
  fi

  # emit one structured output line per tag for the action
  jq -c --null-input \
     --arg src "$src" \
     --arg dst "$dst" \
     --arg tag "$tag" \
     --arg override "$OVERRIDE" \
     --arg status "$status" \
     '{source: $src, destination: $dst, tag: $tag, override: $override, status: $status}' \
    >> "${NUON_ACTIONS_OUTPUT_FILEPATH:-/dev/null}"
done <<EOF
$versions
EOF

if [ "$overall_status" = "failed" ]; then
  echo "warm-up-repository: done with errors; at least one tag failed to copy" >&2
  exit 1
fi

echo "warm-up-repository: done"
