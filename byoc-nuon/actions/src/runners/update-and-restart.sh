#!/usr/bin/env sh
dry_run="$DRY_RUN"
version="$VERSION"
admin_api_url="$ADMIN_API_URL"

OUTPUTS='{}'

echo "getting install runners"
offset="0"
limit="100"
page="0"
url="$admin_api_url/v1/runners?type=install&limit=$limit&offset=$offset"
echo " > url: $url"
runners=`curl -s --max-time 5 -X GET "$url" | jq -r '.[].id'`

for runner_id in $runners; do
  echo "updating runner $runner_id to version $version"
  url="$admin_api_url/v1/runners/$runner_id/settings"

  if [ "$dry_run" = "true" ]; then
    echo "[DRY RUN] Would execute: curl -s --max-time 5 -X PATCH \"$url\" -H \"Content-Type: application/json\" -d \"{\\\"container_image_tag\\\": \\\"$version\\\"}\""
    echo "[DRY RUN] Would execute: curl -X 'POST' \"$admin_api_url/v1/runners/$runner_id/restart\" -H 'accept: application/json' -H 'Content-Type: application/json' -d '{}'"
    response="dry_run_skipped"
  else
    response=$(curl -s --max-time 5 -X PATCH "$url" \
      -H "Content-Type: application/json" \
      -d '{"container_image_tag": "'$version'", "aws_max_instance_lifetime": 604800}')
    echo $container_image_tag

    # append runner.id and response to outputs
    OUTPUTS=$(echo "$OUTPUTS" | jq --arg id "$runner_id" --arg resp "$response" '. + {($id): $resp}')
    curl -s -X 'POST' \
      "$admin_api_url/v1/runners/$runner_id/graceful-shutdown" \
      -H 'accept: application/json' \
      -H 'Content-Type: application/json' \
      -d '{}'
  fi
done

echo $OUTPUTS | jq -c  >> $NUON_ACTIONS_OUTPUT_FILEPATH
