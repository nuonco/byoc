#!/usr/bin/env sh
kubectl --namespace $NAMESPACE get pods
kubectl --namespace $NAMESPACE get pods  -o json | jq -c >> $NUON_ACTIONS_OUTPUT_FILEPATH
