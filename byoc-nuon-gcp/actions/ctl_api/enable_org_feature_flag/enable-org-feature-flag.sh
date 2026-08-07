#!/usr/bin/env bash
set -euo pipefail

: "${FEATURE_FLAG:?FEATURE_FLAG is required}"
: "${CONFIRMATION:?CONFIRMATION is required}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

api_get() {
  local path="$1" destination="$2" status
  status="$(curl --silent --show-error --connect-timeout 10 --max-time 30 --output "$destination" --write-out '%{http_code}' \
    -H 'Accept: application/json' -H "X-Nuon-Admin-Email: $ADMIN_EMAIL" "$ADMIN_API_URL$path")"
  if [[ "$status" != "200" ]]; then
    echo "ERROR: GET $path returned HTTP $status" >&2; cat "$destination" >&2; echo >&2; return 1
  fi
  if ! jq -e . "$destination" >/dev/null 2>&1; then
    echo "ERROR: GET $path returned invalid JSON:" >&2; cat "$destination" >&2; echo >&2; return 1
  fi
}

fetch_orgs_once() {
  local destination="$1" scan="$2" limit=100 offset=0 page count
  printf '[]' >"$destination"
  while :; do
    page="$tmp_dir/$scan-page-$offset.json"
    api_get "/v1/orgs?type=all&limit=$limit&offset=$offset" "$page"
    if ! jq -e 'type == "array" and all(.[]; type == "object" and (.id | type == "string" and length > 0) and (.name | type == "string") and (.features | type == "object"))' "$page" >/dev/null; then
      echo "ERROR: org page at offset $offset has an unexpected shape" >&2; jq -c . "$page" >&2; return 1
    fi
    count="$(jq 'length' "$page")"
    jq -s '.[0] + .[1]' "$destination" "$page" >"$destination.next"; mv "$destination.next" "$destination"
    (( count < limit )) && break
    offset=$((offset + limit))
  done
  if ! jq -e '([.[].id] | length) == ([.[].id] | unique | length)' "$destination" >/dev/null; then
    echo "ERROR: paginated org response contains duplicate IDs" >&2; return 1
  fi
  jq 'sort_by(.id)' "$destination" >"$destination.sorted"; mv "$destination.sorted" "$destination"
}

fetch_stable_orgs() {
  local destination="$1" attempt first second
  for attempt in 1 2 3; do
    first="$tmp_dir/stable-$attempt-first.json"; second="$tmp_dir/stable-$attempt-second.json"
    fetch_orgs_once "$first" "$attempt-first"; fetch_orgs_once "$second" "$attempt-second"
    if cmp -s <(jq -c '[.[].id]' "$first") <(jq -c '[.[].id]' "$second"); then cp "$second" "$destination"; return 0; fi
    echo "WARN: org ID set changed during pagination scan (attempt $attempt/3); retrying" >&2
  done
  echo "ERROR: could not obtain two consecutive org scans with identical ID sets" >&2; return 1
}

feature_count() { jq --arg feature "$2" '[.[] | select(.features[$feature] == true)] | length' "$1"; }
invariant_count() { jq '[.[] | select(.features["control-plane-builds"] == true and .features["org-runner"] == true)] | length' "$1"; }

log_post_state() {
  local orgs="$1" total enabled disabled
  total="$(jq 'length' "$orgs")"; enabled="$(feature_count "$orgs" "$FEATURE_FLAG")"; disabled=$((total - enabled))
  echo "Post-PATCH state for $FEATURE_FLAG: enabled=$enabled disabled=$disabled" >&2
  if (( disabled > 0 )); then
    echo "Organizations still disabled for $FEATURE_FLAG:" >&2
    jq -r --arg feature "$FEATURE_FLAG" '.[] | select(.features[$feature] != true) | "id=\(.id[0:1000]) name=\(.name[0:1000] | @json)"' "$orgs" >&2
  fi
}

if [[ ! "$FEATURE_FLAG" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then echo "ERROR: invalid feature flag format" >&2; exit 1; fi
if [[ "$CONFIRMATION" != "$FEATURE_FLAG" ]]; then echo "ERROR: confirmation must exactly equal the feature key" >&2; exit 1; fi

catalog="$tmp_dir/catalog.json"; api_get "/v1/orgs/admin-features" "$catalog"
if ! jq -e 'type == "array" and all(.[]; type == "object" and (.name | type == "string" and length > 0) and (.description | type == "string")) and ([.[].name] | length == (unique | length))' "$catalog" >/dev/null; then
  echo "ERROR: feature catalog has an unexpected shape or duplicate names" >&2; exit 1
fi
if ! jq -e --arg feature "$FEATURE_FLAG" 'any(.[]; .name == $feature)' "$catalog" >/dev/null; then echo "ERROR: feature flag is not present in the ctl-api feature catalog" >&2; exit 1; fi
description="$(jq -r --arg feature "$FEATURE_FLAG" '.[] | select(.name == $feature) | .description' "$catalog")"

before="$tmp_dir/before.json"; fetch_stable_orgs "$before"
total_before="$(jq 'length' "$before")"; enabled_before="$(feature_count "$before" "$FEATURE_FLAG")"; disabled_before=$((total_before - enabled_before))
cpb_before="$(feature_count "$before" control-plane-builds)"; runner_before="$(feature_count "$before" org-runner)"
invariant_before="$(invariant_count "$before")"
if (( invariant_before != 0 )) && [[ "$FEATURE_FLAG" != "control-plane-builds" && "$FEATURE_FLAG" != "org-runner" ]]; then
  echo "ERROR: $invariant_before org(s) already violate control-plane-builds/org-runner mutual exclusion; refusing unrelated mutation" >&2; exit 1
fi

status="enabled"; after="$tmp_dir/after.json"
if (( disabled_before == 0 && invariant_before == 0 )); then
  status="noop"; cp "$before" "$after"
else
  payload="$tmp_dir/payload.json"; response="$tmp_dir/patch-response.json"
  jq -nc --arg feature "$FEATURE_FLAG" '{features: {($feature): true}}' >"$payload"
  patch_ok=true; http_status="000"
  if ! http_status="$(curl --silent --show-error --connect-timeout 10 --max-time 300 --request PATCH \
    --output "$response" --write-out '%{http_code}' -H 'Accept: application/json' -H 'Content-Type: application/json' \
    -H "X-Nuon-Admin-Email: $ADMIN_EMAIL" --data-binary "@$payload" "$ADMIN_API_URL/v1/orgs/admin-features")"; then
    patch_ok=false; echo "ERROR: PATCH /v1/orgs/admin-features failed during transport" >&2
  elif [[ "$http_status" != "200" ]]; then
    patch_ok=false; echo "ERROR: PATCH /v1/orgs/admin-features returned HTTP $http_status" >&2; cat "$response" >&2; echo >&2
  elif ! jq -e 'type == "object"' "$response" >/dev/null 2>&1; then
    patch_ok=false; echo "ERROR: PATCH /v1/orgs/admin-features returned invalid JSON or the wrong shape" >&2; cat "$response" >&2; echo >&2
  fi
  # PATCH is deliberately never retried. Always inspect its possibly-partial post-state.
  fetch_stable_orgs "$after"
  log_post_state "$after"
  [[ "$patch_ok" == true ]] || exit 1
fi

total_after="$(jq 'length' "$after")"; enabled_after="$(feature_count "$after" "$FEATURE_FLAG")"; disabled_after=$((total_after - enabled_after))
cpb_after="$(feature_count "$after" control-plane-builds)"; runner_after="$(feature_count "$after" org-runner)"
invariant_after="$(invariant_count "$after")"
if (( disabled_after != 0 )); then log_post_state "$after"; echo "ERROR: verification failed: $disabled_after org(s) still have $FEATURE_FLAG disabled" >&2; exit 1; fi
if (( invariant_after != 0 )); then echo "ERROR: verification failed: $invariant_after org(s) have both control-plane-builds and org-runner enabled" >&2; exit 1; fi

jq -nc --arg feature "$FEATURE_FLAG" --arg description "$description" --arg status "$status" \
  --argjson total_before "$total_before" --argjson enabled_before "$enabled_before" --argjson disabled_before "$disabled_before" \
  --argjson total_after "$total_after" --argjson enabled_after "$enabled_after" --argjson disabled_after "$disabled_after" \
  --argjson cpb_before "$cpb_before" --argjson cpb_after "$cpb_after" --argjson runner_before "$runner_before" --argjson runner_after "$runner_after" \
  --argjson changed "$((enabled_after - enabled_before))" --argjson invariant_before "$invariant_before" --argjson invariant_after "$invariant_after" '
  {feature: $feature, description: $description, status: $status,
   before: {total_orgs: $total_before, enabled: $enabled_before, disabled: $disabled_before},
   after: {total_orgs: $total_after, enabled: $enabled_after, disabled: $disabled_after}, changed: $changed,
   coupled_flags: {before: {"control-plane-builds": $cpb_before, "org-runner": $runner_before}, after: {"control-plane-builds": $cpb_after, "org-runner": $runner_after}},
   invariant_before: $invariant_before, invariant_count: $invariant_after}' >>"$NUON_ACTIONS_OUTPUT_FILEPATH"
