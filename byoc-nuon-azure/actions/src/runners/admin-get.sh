#!/usr/bin/env bash

set -e
set -o pipefail
set -u

admin_api_addr="$ADMIN_API_URL"
type="$RUNNER_TYPE"

# TODO(fd): if the type is an empty string, compose the url w/out a type
url="$admin_api_addr/v1/runners?type=$type"


curl --max-time 5 -q -s $url    \
  -H 'accept: application/json' \
  -H 'X-Nuon-Admin-Email: jon@nuon.co' \
  | jq -c 'map({(.id): .}) | add // {}' >> $NUON_ACTIONS_OUTPUT_FILEPATH
