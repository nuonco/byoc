#!/usr/bin/env sh

set -e
set -o pipefail
set -u

# we declare this here so we fail early if the value is not set
admin_api_url="$ADMIN_API_URL"

RESPONSE_COUNTS='{"orgs": {}, "installs": {}}'

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
    http_code=$(curl -s --max-time 10 -X PATCH "$url" \
      -H "Content-Type: application/json" \
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

# update org runners
echo "getting org runners"
url="$admin_api_url/v1/runners?type=org&limit=$limit&offset=$offset"
org_runner_ids=`curl -s --max-time 5 -X GET "$url" | jq -r '.[].id'`

update_runners "orgs" "$org_runner_ids"

echo "getting install runners"
url="$admin_api_url/v1/runners?type=install&limit=$limit&offset=$offset"
install_runner_ids=`curl -s --max-time 5 -X GET "$url" | jq -r '.[].id'`

update_runners "installs" "$install_runner_ids"

echo "{\"responses\": $RESPONSE_COUNTS}" | jq -c . >> $NUON_ACTIONS_OUTPUT_FILEPATH
