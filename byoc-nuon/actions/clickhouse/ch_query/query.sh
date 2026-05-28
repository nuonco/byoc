#!/usr/bin/env sh

kubectl exec -n clickhouse chi-clickhouse-installation-simple-0-0-0 -- clickhouse client -q "$QUERY"
