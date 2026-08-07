#!/usr/bin/env bash
set -euo pipefail

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

case "${OUTPUT_MODE:-}" in
  summary|orgs) ;;
  *) echo "ERROR: OUTPUT_MODE must be summary or orgs" >&2; exit 1 ;;
esac

api_get() {
  local path="$1" destination="$2" status
  status="$(curl --silent --show-error --connect-timeout 10 --max-time 30 \
    --output "$destination" --write-out '%{http_code}' \
    -H 'Accept: application/json' \
    -H "X-Nuon-Admin-Email: $ADMIN_EMAIL" \
    "$ADMIN_API_URL$path")"
  if [[ "$status" != "200" ]]; then
    echo "ERROR: GET $path returned HTTP $status" >&2
    cat "$destination" >&2; echo >&2
    return 1
  fi
  if ! jq -e . "$destination" >/dev/null 2>&1; then
    echo "ERROR: GET $path returned invalid JSON:" >&2
    cat "$destination" >&2; echo >&2
    return 1
  fi
}

fetch_orgs_once() {
  local destination="$1" scan="$2" limit=100 offset=0 page count
  printf '[]' >"$destination"
  while :; do
    page="$tmp_dir/$scan-page-$offset.json"
    api_get "/v1/orgs?type=all&limit=$limit&offset=$offset" "$page"
    if ! jq -e 'type == "array" and all(.[]; type == "object" and (.id | type == "string" and length > 0) and (.name | type == "string") and (.features | type == "object"))' "$page" >/dev/null; then
      echo "ERROR: org page at offset $offset has an unexpected shape" >&2
      jq -c . "$page" >&2
      return 1
    fi
    count="$(jq 'length' "$page")"
    jq -s '.[0] + .[1]' "$destination" "$page" >"$destination.next"
    mv "$destination.next" "$destination"
    (( count < limit )) && break
    offset=$((offset + limit))
  done
  if ! jq -e '([.[].id] | length) == ([.[].id] | unique | length)' "$destination" >/dev/null; then
    echo "ERROR: paginated org response contains duplicate IDs" >&2
    return 1
  fi
  jq 'sort_by(.id)' "$destination" >"$destination.sorted"
  mv "$destination.sorted" "$destination"
}

fetch_stable_orgs() {
  local destination="$1" attempt first second
  for attempt in 1 2 3; do
    first="$tmp_dir/stable-$attempt-first.json"
    second="$tmp_dir/stable-$attempt-second.json"
    fetch_orgs_once "$first" "$attempt-first"
    fetch_orgs_once "$second" "$attempt-second"
    if cmp -s <(jq -c '[.[].id]' "$first") <(jq -c '[.[].id]' "$second"); then
      cp "$second" "$destination"
      return 0
    fi
    echo "WARN: org ID set changed during pagination scan (attempt $attempt/3); retrying" >&2
  done
  echo "ERROR: could not obtain two consecutive org scans with identical ID sets" >&2
  return 1
}

emit_line() {
  local line="$1" byte_count
  byte_count="$(LC_ALL=C printf '%s\n' "$line" | wc -c | tr -d '[:space:]')"
  if (( byte_count >= 65536 )); then
    echo "ERROR: action output line would exceed the runner's 64 KiB limit" >&2
    return 1
  fi
  printf '%s\n' "$line" >>"$NUON_ACTIONS_OUTPUT_FILEPATH"
}

catalog="$tmp_dir/catalog.json"
api_get "/v1/orgs/admin-features" "$catalog"
if ! jq -e 'type == "array" and all(.[]; type == "object" and (.name | type == "string" and length > 0) and (.description | type == "string")) and ([.[].name] | length == (unique | length))' "$catalog" >/dev/null; then
  echo "ERROR: feature catalog has an unexpected shape or duplicate names" >&2
  jq -c . "$catalog" >&2
  exit 1
fi

orgs="$tmp_dir/orgs.json"
fetch_stable_orgs "$orgs"

if [[ "$OUTPUT_MODE" == "summary" ]]; then
  summary="$(jq -nc --arg updated_at "$(TZ=UTC date +%Y-%m-%dT%H:%M:%SZ)" --slurpfile catalog "$catalog" --slurpfile orgs "$orgs" '
    ($catalog[0]) as $catalog | ($orgs[0]) as $orgs | {
      updated_at: $updated_at,
      total_orgs: ($orgs | length),
      features: [$catalog[] as $feature |
        ([ $orgs[] | select(.features[$feature.name] == true) ] | length) as $enabled |
        {name: $feature.name, description: $feature.description, enabled: $enabled, disabled: (($orgs | length) - $enabled)}]
    }')"
  emit_line "$summary"
else
  while IFS= read -r org; do
    emit_line "$org"
  done < <(jq -c '.[] | {(.id): {id, name, features: (.features // {})}}' "$orgs")
fi
