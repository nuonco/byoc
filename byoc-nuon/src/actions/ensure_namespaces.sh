#!/usr/bin/env bash

set -e
set -o pipefail
set -u

echo "[namespaces] ensuring"
kubectl create namespace clickhouse
kubectl create namespace ctl-api
kubectl create namespace dashboard-ui
