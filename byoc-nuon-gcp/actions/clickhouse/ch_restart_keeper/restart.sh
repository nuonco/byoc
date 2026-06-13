#!/usr/bin/env sh

kubectl scale statefulsets -n clickhouse chk-clickhouse-keeper-chk-simple-0-0 --replicas=0
kubectl scale statefulsets -n clickhouse chk-clickhouse-keeper-chk-simple-0-1 --replicas=0
kubectl scale statefulsets -n clickhouse chk-clickhouse-keeper-chk-simple-0-2 --replicas=0
sleep 3
kubectl scale statefulsets -n clickhouse chk-clickhouse-keeper-chk-simple-0-0 --replicas=1
kubectl scale statefulsets -n clickhouse chk-clickhouse-keeper-chk-simple-0-1 --replicas=1
kubectl scale statefulsets -n clickhouse chk-clickhouse-keeper-chk-simple-0-2 --replicas=1
