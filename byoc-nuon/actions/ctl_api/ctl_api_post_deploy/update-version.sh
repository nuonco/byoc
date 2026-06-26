#!/usr/bin/env sh

set -e
set -o pipefail
set -u

# we declare this here so we fail early if the value is not set
admin_api_url="$ADMIN_API_URL"
admin_email="jon@nuon.co"

RESPONSE_COUNTS='{"orgs": {}, "installs": {}}'

# wait_for_admin polls the admin API until it answers, tolerating curl-level
# failures (DNS not resolvable yet = exit 6, connection refused = exit 7,
# timeout = exit 28). Without this the first list-runners curl below fails
# under set -e/pipefail and the whole step errors out.
wait_for_admin() {
  attempts=0
  max_attempts=30   # ~5 min at 10s
  while [ "$attempts" -lt "$max_attempts" ]; do
    attempts=$((attempts + 1))
    rc=0
    code=$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' \
      "$admin_api_url/v1/runners?type=org&limit=1&offset=0") || rc=$?
    if [ "$rc" -eq 0 ] && [ "$code" -ge 200 ] && [ "$code" -lt 500 ]; then
      echo "admin API reachable ($admin_api_url, http $code) after $attempts attempt(s)"
      return 0
    fi
    echo "waiting for admin API ($admin_api_url): attempt $attempts/$max_attempts (curl rc=$rc, http=$code)"
    sleep 10
  done
  echo "ERROR: admin API never became reachable at $admin_api_url after $max_attempts attempts" >&2
  return 1
}

wait_for_admin

echo "getting RUNNER_CONTAINER_IMAGE_TAG from ctl-api configmap"
RUNNER_CONTAINER_IMAGE_TAG=$(kubectl get -n ctl-api configmaps ctl-api -o yaml |\
  grep RUNNER_CONTAINER_IMAGE_TAG |\
  cut -d ':' -f 2 |\
  sed 's/ //g')

# update_runners iterates a list of runner ids and PATCHes each runner's
# settings to the current RUNNER_CONTAINER_IMAGE_TAG. Per-runner-type results
# accumulate into RESPONSE_COUNTS.[$type_key] as {<http_code>: N, errors: [..]}.
# A curl-level failure (e.g. exit 28 = timeout) appends the runner id to
# errors and continues; HTTP responses are tallied under their status code.
update_runners() {
  type_key="$1"
  runner_ids="$2"
  # count via positional params so we can show "n of y" progress
  set -- $runner_ids
  total=$#
  index=0
  for runner_id in $runner_ids; do
    index=$((index + 1))
    echo "[$index of $total] updating $type_key runner $runner_id to version $RUNNER_CONTAINER_IMAGE_TAG"
    url="$admin_api_url/v1/runners/$runner_id/settings"

    curl_rc=0
    http_code=$(curl -s --max-time 30 -X PATCH "$url" \
      -H "Content-Type: application/json"   \
      -H "X-Nuon-Admin-Email: $admin_email" \
      -d "{\"container_image_tag\": \"$RUNNER_CONTAINER_IMAGE_TAG\", \"binary_version\": \"$RUNNER_CONTAINER_IMAGE_TAG\"}" \
      -w "\n%{http_code}" \
      -o /tmp/response_body.json) || curl_rc=$?

    if [ "$curl_rc" -ne 0 ]; then
      echo "ERROR: curl failed (exit $curl_rc) for $type_key runner $runner_id at $url" >&2
      RESPONSE_COUNTS=$(echo "$RESPONSE_COUNTS" | jq \
        --arg type "$type_key" \
        --arg id "$runner_id" \
        '.[$type].errors = ((.[$type].errors // []) + [$id])')
      continue
    fi

    # print response as inline json
    if jq -c . /tmp/response_body.json 2>/dev/null; then
      :
    else
      cat /tmp/response_body.json
      echo ""
    fi

    # increment counter for this status code, scoped to the runner type
    RESPONSE_COUNTS=$(echo "$RESPONSE_COUNTS" | jq \
      --arg type "$type_key" \
      --arg code "$http_code" \
      '.[$type][$code] = ((.[$type][$code] // 0) + 1)')
  done
}


offset="0"
limit="100"

# list_runner_ids fetches the runner ids for a given type. This step runs
# right after restart-deployments rolls the ctl-api pods, so a transient
# curl failure here is expected; we retry, and if we still fail we print
# the exact curl exit code instead of dying blind. Sets the global
# RUNNER_IDS.
list_runner_ids() {
  list_type="$1"
  url="$admin_api_url/v1/runners?type=$list_type&limit=$limit&offset=$offset"
  attempts=0
  max_attempts=10
  while [ "$attempts" -lt "$max_attempts" ]; do
    attempts=$((attempts + 1))
    rc=0
    body=$(curl -s --max-time 15 "$url") || rc=$?
    if [ "$rc" -eq 0 ]; then
      RUNNER_IDS=$(printf '%s' "$body" | jq -r '.[].id')
      return 0
    fi
    echo "  curl for $list_type runners failed (exit $rc) at $url; attempt $attempts/$max_attempts" >&2
    sleep 6
  done
  echo "ERROR: could not list $list_type runners after $max_attempts attempts (last curl exit $rc) at $url" >&2
  return 1
}

# update org runners
echo "getting org runners"
list_runner_ids "org"
update_runners "orgs" "$RUNNER_IDS"

echo "getting install runners"
list_runner_ids "install"
update_runners "installs" "$RUNNER_IDS"

echo "{\"responses\": $RESPONSE_COUNTS}" | jq -c . >> $NUON_ACTIONS_OUTPUT_FILEPATH
