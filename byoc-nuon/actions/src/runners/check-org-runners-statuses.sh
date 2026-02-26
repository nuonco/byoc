#!/usr/bin/env sh

set -e
set -o pipefail
set -u

admin_api_url="$ADMIN_API_URL"

outputs='{}'

echo "getting org runners"
runners=`curl -s "$admin_api_url/v1/runners?type=org&limit=100" | jq -c`
for runner_id in `echo $runners | jq -r '.[].id'`; do
  echo " > checking: runner id:$runner_id"
  # ensure the ns exists
  if kubectl get namespace $runner_id; then
    # print it to the screen
    kubectl --namespace $runner_id get deployments/runner-$runner_id
    # grab status as json
    runner_status=`kubectl --namespace $runner_id get deployments/runner-$runner_id -o json | jq '.status'`
    output=`jq --null-input --arg runnerID "$runner_id" --argjson runnerStatus "$runner_status" '{$runnerID: $runnerStatus}'`
    outputs=`echo $outputs | jq ".+=$output"`
  else
    echo " ! namespace not found. consider reviewing the corresponding org status. skipping."
  fi
done

echo $outputs >> $NUON_ACTIONS_OUTPUT_FILEPATH
