#!/usr/bin/env bash

set -e
set -o pipefail
set -u

admin_api_addr="$ADMIN_API_URL"
admin_email='jon@nuon.co'

RUNNER_CONTAINER_IMAGE_TAG=$(kubectl get -n ctl-api configmaps ctl-api -o yaml |\
  grep RUNNER_CONTAINER_IMAGE_TAG |\
  cut -d ':' -f 2 |\
  sed 's/ //g')

echo "[ctl_api promote] executing ctl-api promote callback"
curl --max-time 60 -s -X 'POST'          \
  "$admin_api_addr/v1/general/promotion" \
  -H "X-Nuon-Admin-Email: $admin_email"  \
  --data '{"tag":"'"$RUNNER_CONTAINER_IMAGE_TAG"'"}'
