#!/usr/bin/env bash
#
# warm-up-repository
#
# Warms up the install's public ECR runner repository by importing every runner
# image version currently in use across the install's runners.
#
# Discovers the set of versions by querying ClickHouse
# (ctl_api.latest_runner_heart_beats) for the distinct `version` values reported
# by runner heartbeats, then imports each tag from the upstream Nuon public ECR
# registry (SOURCE_IMAGE_URL) into the install's public ECR runner repository
# (RUNNER_REPOSITORY_URI). This is ecr_runner_import fanned out over every
# active version instead of just the ctl-api configmap tag.
#
# Uses `oras` for the copy. ORAS preserves the source manifest verbatim
# (multi-arch indexes, layer digests, etc.). The oras CLI is expected to be
# bundled in the runner image; we just resolve it on PATH.
#
# Env:
#   SOURCE_IMAGE_URL       - upstream image to pull from, e.g.
#                            public.ecr.aws/p7e3r5y0/runner (hardcoded below)
#   RUNNER_REPOSITORY_URI  - destination public ECR repo URI (this install)
#   OVERRIDE               - "true" to overwrite tags that already exist in the
#                            destination; "false" (default) to skip them.
set -euo pipefail

SOURCE_IMAGE_URL="public.ecr.aws/p7e3r5y0/runner"
: "${RUNNER_REPOSITORY_URI:?RUNNER_REPOSITORY_URI is required}"
OVERRIDE="${OVERRIDE:-false}"

CH_POD="chi-clickhouse-installation-simple-0-0-0"
# Single bare statement -- no trailing ';', WHERE, or FORMAT. clickhouse-client
# -q already emits TabSeparated (one value per line) for a non-interactive
# query, and empty/blank versions are filtered out in the import loop below.
# A stray ';' makes the client see two statements ("Multi-statements are not
# allowed"), so keep this to a single SELECT.
CH_QUERY="SELECT DISTINCT version FROM ctl_api.latest_runner_heart_beats"

echo "warm-up-repository: querying ClickHouse for distinct runner versions"
versions=$(kubectl exec -n clickhouse "$CH_POD" -- \
  clickhouse client -d ctl_api -q "$CH_QUERY")

if [ -z "$versions" ]; then
  echo "warm-up-repository: no versions found in ctl_api.latest_runner_heart_beats; nothing to do" >&2
  exit 0
fi

echo "warm-up-repository: discovered versions:"
echo "$versions" | sed 's/^/  - /'

if ! command -v oras >/dev/null 2>&1; then
  echo "warm-up-repository: oras not found on PATH; expected to be bundled in the runner image" >&2
  exit 1
fi
oras_bin=$(command -v oras)

# auth to public.ecr.aws (us-east-1 is the only ECR Public endpoint).
# Same auth covers anonymous-pullable upstream public.ecr.aws/* sources and
# authenticated push to the install's repo. Requires the maintenance role to
# have ecr-public:GetAuthorizationToken and sts:GetServiceBearerToken.
echo "warm-up-repository: authenticating to public.ecr.aws"
aws ecr-public get-login-password --region us-east-1 \
  | "$oras_bin" login --username AWS --password-stdin public.ecr.aws

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
