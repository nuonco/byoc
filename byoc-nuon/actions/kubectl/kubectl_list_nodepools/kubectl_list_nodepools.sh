#!/usr/bin/env sh
results=`kubectl get nodepools -o json | jq -c`
echo $results | jq
echo $results >> $NUON_ACTIONS_OUTPUT_FILEPATH
