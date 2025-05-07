#!/usr/bin/env bash

set -e
set -o pipefail
set -u

echo "[clickhouse init] kubectl auth whoami"
kubectl auth whoami

# TODO: set up a standalone container to do this
kubectl exec -n clickhouse chi-clickhouse-installation-simple-0-0-0 -- clickhouse client -q "CREATE DATABASE IF NOT EXISTS ctl_api ON CLUSTER 'simple';"
