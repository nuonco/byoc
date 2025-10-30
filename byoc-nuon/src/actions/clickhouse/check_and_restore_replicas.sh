#!/usr/bin/env sh

set -e
set -u
set -o pipefail

echo "getting a pod"
pod=`kubectl -n clickhouse get pods | grep installation | cut -d ' ' -f 1 | tail -n 1`

echo "getting read-only tables"
tables=`kubectl --namespace=clickhouse exec -i $pod -- clickhouse client -d ctl_api -q "SELECT table FROM system.replicas WHERE database = 'ctl_api' AND is_readonly = 1"`
echo $tables

# act on replicas w/ a bad status
for table in $tables; do
    echo " > table replication in need of repair: $table"
    kubectl --namespace=clickhouse exec -i $pod -- clickhouse client -d ctl_api -q "system restore replica on cluster simple ctl_api.$table;"
    echo " > table replication restore - taking a small nap $table"
    sleep 1
done

outputs=$(echo "$tables" | jq -R -s -c 'split("\n") | map(select(length > 0)) | {repaired_tables: .}')
echo $outputs >> $NUON_ACTIONS_OUTPUT_FILEPATH
