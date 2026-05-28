#!/usr/bin/env sh
results=`kubectl get nodeclaims $NODEPOOL -o json | jq -c`
echo $results | jq -c
echo $results >> $NUON_ACTIONS_OUTPUT_FILEPATH
