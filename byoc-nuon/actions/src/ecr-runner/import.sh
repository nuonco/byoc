#!/usr/bin/env bash
#
# ecr-runner-import
#
# Imports a single semver tag of the upstream Nuon runner image
# (SOURCE_IMAGE_URL, sourced from the `runner_image_url` input) into the
# install's public ECR runner repository (RUNNER_REPOSITORY_URI, from the
# `runner_repository` component).
#
# Uses `oras` for the copy. ORAS preserves the source manifest verbatim
# (multi-arch indexes, layer digests, etc.). The oras CLI is expected to be
# bundled in the runner image; we just resolve it on PATH.
#
# Env:
#   SOURCE_IMAGE_URL       - upstream image to pull from, e.g.
#                            public.ecr.aws/p7e3r5y0/runner
#   RUNNER_REPOSITORY_URI  - destination public ECR repo URI (this install)
#   OVERRIDE               - "true" to overwrite the tag if it already exists
#                            in the destination; "false" (default) to skip.
#
# RUNNER_VERSION is read from the ctl-api configmap
# (configmaps/ctl-api -n ctl-api, key RUNNER_CONTAINER_IMAGE_TAG), the same
# way shared/actions/src/runners/update-version.sh does.
set -euo pipefail

SOURCE_IMAGE_URL="public.ecr.aws/p7e3r5y0/runner"
: "${RUNNER_REPOSITORY_URI:?RUNNER_REPOSITORY_URI is required}"
OVERRIDE="${OVERRIDE:-false}"

echo "ecr-runner-import: reading RUNNER_CONTAINER_IMAGE_TAG from ctl-api configmap"
RUNNER_VERSION=$(kubectl get -n ctl-api configmaps ctl-api -o yaml \
  | grep RUNNER_CONTAINER_IMAGE_TAG \
  | cut -d ':' -f 2 \
  | sed 's/ //g')
if [ -z "$RUNNER_VERSION" ]; then
  echo "ecr-runner-import: RUNNER_CONTAINER_IMAGE_TAG not found in ctl-api configmap" >&2
  exit 1
fi

if ! command -v oras >/dev/null 2>&1; then
  echo "ecr-runner-import: oras not found on PATH; expected to be bundled in the runner image" >&2
  exit 1
fi
oras_bin=$(command -v oras)

# auth to public.ecr.aws (us-east-1 is the only ECR Public endpoint).
# Same auth covers anonymous-pullable upstream public.ecr.aws/* sources and
# authenticated push to the install's repo. Requires the maintenance role to
# have ecr-public:GetAuthorizationToken and sts:GetServiceBearerToken.
echo "ecr-runner-import: authenticating to public.ecr.aws"
aws ecr-public get-login-password --region us-east-1 \
  | "$oras_bin" login --username AWS --password-stdin public.ecr.aws

src="${SOURCE_IMAGE_URL%/}"
dst="${RUNNER_REPOSITORY_URI%/}"
tag="${RUNNER_VERSION// /}"

status="copied"

# If OVERRIDE is not enabled, skip when the tag already exists in the destination.
if [ "$OVERRIDE" != "true" ]; then
  if "$oras_bin" manifest fetch --descriptor "${dst}:${tag}" >/dev/null 2>&1; then
    echo "ecr-runner-import: ${dst}:${tag} already exists; skipping (set OVERRIDE=true to overwrite)"
    status="skipped"
  fi
fi

if [ "$status" = "copied" ]; then
  echo "ecr-runner-import: copying ${src}:${tag} -> ${dst}:${tag}"
  if ! "$oras_bin" copy "${src}:${tag}" "${dst}:${tag}"; then
    echo "ecr-runner-import: failed to copy tag ${tag}" >&2
    status="failed"
  fi
fi

# emit structured output for the action
jq -c --null-input \
   --arg src "$src" \
   --arg dst "$dst" \
   --arg tag "$tag" \
   --arg override "$OVERRIDE" \
   --arg status "$status" \
   '{source: $src, destination: $dst, tag: $tag, override: $override, status: $status}' \
  >> "${NUON_ACTIONS_OUTPUT_FILEPATH:-/dev/null}"

if [ "$status" = "failed" ]; then
  exit 1
fi

echo "ecr-runner-import: done; ${tag} ${status}"
