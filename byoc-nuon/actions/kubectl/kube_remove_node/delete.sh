#!/bin/bash

set -e
set -o pipefail
set -u

kubectl delete node $NODE_NAME
