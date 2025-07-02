#!/usr/bin/env bash

set -e
set -o pipefail
set -u

admin_api_url="$ADMIN_API_URL"
tag="$TAG"

# TODO: at some point we'll have to paginate through results instead of fetching a fixed count
echo "[runner-settings-group] get org runners"
runners=`curl -s "$admin_api_url/v1/runners?type=org&limit=100" | jq -c`

echo "[runner-settings-group] set org runner container_image_tag to $tag"
for runner_id in `echo $runners | jq -r '.[].id'`; do
  echo " > updating: runner group settings for $runner_id"
  curl -s -X 'PATCH' \
    "$admin_api_url/v1/runners/$runner_id/settings" \
    -H 'accept: application/json' \
    -H 'Content-Type: application/json' \
    -d '{"container_image_tag": "'tag'"}'
done

echo "[runner-settings-group] get install runners"
runners=`curl -s "$admin_api_url/v1/runners?type=install&limit=100" | jq -c`

echo "[runner-settings-group] set install runner container_image_tag to $tag"
for runner_id in `echo $runners | jq -r '.[].id'`; do
  echo " > updating: runner group settings for $runner_id"
  curl -s -X 'PATCH' \
    "$admin_api_url/v1/runners/$runner_id/settings" \
    -H 'accept: application/json' \
    -H 'Content-Type: application/json' \
    -d '{"container_image_tag": "'tag'"}'
done
