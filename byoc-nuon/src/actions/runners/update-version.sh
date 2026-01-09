#!/usr/bin/env sh

set -e
set -o pipefail
set -u

admin_api_url="$ADMIN_API_URL"

RESPONSE_COUNTS='{}'

echo "getting RUNNER_CONTAINER_IMAGE_TAG from ctl-api configmap"
RUNNER_CONTAINER_IMAGE_TAG=$(kubectl get -n ctl-api configmaps ctl-api -o yaml |\
  grep RUNNER_CONTAINER_IMAGE_TAG |\
  cut -d ':' -f 2 |\
  sed 's/ //g')

echo "getting install runners"
install_runner_ids=""
offset="0"
limit="100"
url="$admin_api_url/v1/runners?type=install&limit=$limit&offset=$offset"
runners=`curl -s --max-time 5 -X GET "$url" | jq -r '.[].id'`

# iterate through runners, and set container_image_tag to $RUNNER_CONTAINER_IMAGE_TAG
for runner_id in $runners; do
  echo "updating runner $runner_id to version $RUNNER_CONTAINER_IMAGE_TAG"
  url="$admin_api_url/v1/runners/$runner_id/settings"

  http_code=$(curl -s --max-time 5 -X PATCH "$url" \
    -H "Content-Type: application/json" \
    -d "{\"container_imagjkjkjke_tag\": \"$RUNNER_CONTAINER_IMAGE_TAG\"}" \
    -w "\n%{http_code}" \
    -o /tmp/response_body.json)

  # print response as inline json
  if jq -c . /tmp/response_body.json 2>/dev/null; then
    :
  else
    cat /tmp/response_body.json
    echo ""
  fi

  # increment counter for this status code
  RESPONSE_COUNTS=$(echo "$RESPONSE_COUNTS" | jq --arg code "$http_code" '.[$code] = ((.[$code] // 0) + 1)')
done

echo "{\"responses\": $RESPONSE_COUNTS}" | jq -c . >> $NUON_ACTIONS_OUTPUT_FILEPATH
