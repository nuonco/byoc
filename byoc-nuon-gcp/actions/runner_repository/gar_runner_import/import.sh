#!/usr/bin/env bash
#
# gar-runner-import
#
# Imports a single semver tag of the upstream Nuon runner image
# (SOURCE_IMAGE_URL) into the install's Artifact Registry runner repository
# (RUNNER_REPOSITORY_URI, from the `runner_repository` component).
#
# Uses `oras` for the copy. ORAS preserves the source manifest verbatim
# (multi-arch indexes, layer digests, etc.). The oras CLI is expected to be
# bundled in the runner image; we just resolve it on PATH.
#
# Env:
#   RUNNER_REPOSITORY_URI  - destination Artifact Registry repo URI (this install)
#   OVERRIDE               - "true" to overwrite the tag if it already exists
#                            in the destination; "false" (default) to skip.
#
# RUNNER_VERSION is read from the ctl-api configmap
# (configmaps/ctl-api -n ctl-api, key RUNNER_CONTAINER_IMAGE_TAG).
set -euo pipefail

SOURCE_IMAGE_URL="public.ecr.aws/p7e3r5y0/runner"
: "${RUNNER_REPOSITORY_URI:?RUNNER_REPOSITORY_URI is required}"
OVERRIDE="${OVERRIDE:-false}"

echo "gar-runner-import: reading RUNNER_CONTAINER_IMAGE_TAG from ctl-api configmap"
RUNNER_VERSION=$(kubectl get -n ctl-api configmaps ctl-api \
  -o jsonpath='{.data.RUNNER_CONTAINER_IMAGE_TAG}')
if [ -z "$RUNNER_VERSION" ]; then
  echo "gar-runner-import: RUNNER_CONTAINER_IMAGE_TAG not found in ctl-api configmap" >&2
  exit 1
fi

if ! command -v oras >/dev/null 2>&1; then
  echo "gar-runner-import: oras not found on PATH; expected to be bundled in the runner image" >&2
  exit 1
fi
oras_bin=$(command -v oras)

# Only the destination needs credentials: public.ecr.aws serves the upstream
# anonymously, and there are no AWS credentials to log in with from GCP anyway.
#
# No --impersonate-service-account here: action steps already run with
# CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT set to the operation identity, whose
# maintenance role carries artifactregistry uploadArtifacts + tags.create.
gar_host="${RUNNER_REPOSITORY_URI%%/*}"
echo "gar-runner-import: authenticating to $gar_host"
gcloud auth print-access-token \
  | "$oras_bin" login -u oauth2accesstoken --password-stdin "$gar_host"

src="${SOURCE_IMAGE_URL%/}"
dst="${RUNNER_REPOSITORY_URI%/}"
tag="${RUNNER_VERSION// /}"

status="copied"

# If OVERRIDE is not enabled, skip when the tag already exists in the destination.
if [ "$OVERRIDE" != "true" ]; then
  if "$oras_bin" manifest fetch --descriptor "${dst}:${tag}" >/dev/null 2>&1; then
    echo "gar-runner-import: ${dst}:${tag} already exists; skipping (set OVERRIDE=true to overwrite)"
    status="skipped"
  fi
fi

if [ "$status" = "copied" ]; then
  echo "gar-runner-import: copying ${src}:${tag} -> ${dst}:${tag}"
  if ! "$oras_bin" copy "${src}:${tag}" "${dst}:${tag}"; then
    echo "gar-runner-import: failed to copy tag ${tag}" >&2
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

echo "gar-runner-import: done; ${tag} ${status}"
