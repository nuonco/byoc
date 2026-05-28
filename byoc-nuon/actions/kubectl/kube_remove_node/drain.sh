#!/bin/bash

set -e
set -o pipefail
set -u

kubectl drain $NODE_NAME --ignore-daemonsets
sleep 10
