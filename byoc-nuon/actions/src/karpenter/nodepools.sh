#!/bin/bash

set -e
set -o pipefail
set -u


kubectl auth whoami | jq -c

kubectl get --all-namespaces nodepools -o json >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
