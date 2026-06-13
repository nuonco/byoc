#!/usr/bin/env bash

set -e
set -o pipefail
set -u

admin_api_addr="$ADMIN_API_URL"

# get org runners
org_runners=$(curl --max-time 5 -q -s \
  "$admin_api_addr/v1/runners?type=org&limit=100" \
  -H 'accept: application/json' \
  -H 'X-Nuon-Admin-Email: jon@nuon.co')

# get install runners
install_runners=$(curl --max-time 5 -q -s \
  "$admin_api_addr/v1/runners?type=install&limit=100" \
  -H 'accept: application/json' \
  -H 'X-Nuon-Admin-Email: jon@nuon.co')

# merge into single list
runners=$(echo "$org_runners" "$install_runners" | jq -s 'add')

# emit one JSON object per runner — keeps each output line well under
# the runner's bufio.Scanner token limit even with many/large settings.
for runner_id in $(echo "$runners" | jq -r '.[].id'); do
  org_id=$(echo "$runners" | jq -r --arg id "$runner_id" '.[] | select(.id == $id) | .org_id')
  settings=$(curl --max-time 5 -q -s \
    "$admin_api_addr/v1/runners/$runner_id/settings" \
    -H 'accept: application/json' \
    -H 'X-Nuon-Admin-Email: jon@nuon.co')

  # project only the fields the README renders — keeps each line well under
  # the runner's bufio.Scanner token limit regardless of how large the full
  # settings doc (metadata, groups, etc.) grows.
  jq -nc --arg id "$runner_id" --arg org "$org_id" --argjson settings "$settings" \
    '{($id): {
       org_id: $org,
       type: ($settings.metadata["runner.type"] // "unknown"),
       settings: {
         container_image_url:       $settings.container_image_url,
         container_image_tag:       $settings.container_image_tag,
         aws_instance_type:         $settings.aws_instance_type,
         aws_max_instance_lifetime: $settings.aws_max_instance_lifetime,
         enable_logging:            $settings.enable_logging,
         logging_level:             $settings.logging_level,
         enable_sentry:             $settings.enable_sentry,
         enable_metrics:            $settings.enable_metrics,
         heart_beat_timeout:        $settings.heart_beat_timeout,
         runner_api_url:            $settings.runner_api_url,
         runner_group_id:           $settings.runner_group_id,
         created_at:                $settings.created_at,
         updated_at:                $settings.updated_at,
         metadata: {
           "org.name":       ($settings.metadata["org.name"]       // "unknown"),
           "runner.platform":($settings.metadata["runner.platform"]// "unknown"),
           "runner.type":    ($settings.metadata["runner.type"]    // "unknown")
         }
       }
     }}' \
    >> $NUON_ACTIONS_OUTPUT_FILEPATH
done
