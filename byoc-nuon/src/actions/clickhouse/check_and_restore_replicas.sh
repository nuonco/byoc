#!/usr/bin/env sh

set -e
set -u
set -o pipefail

echo "getting a pod"
pod=`kubectl -n clickhouse get pods | grep installation | cut -d ' ' -f 1 | tail -n 1`

echo "getting read-only tables"
# NOTE(fd): we reverse the sort to get the runner_* tables in first.
tables=`kubectl --namespace=clickhouse exec -i $pod -- clickhouse client -d ctl_api -q "SELECT table FROM system.replicas WHERE database = 'ctl_api' AND is_readonly = 1" | sort -rn`
echo $tables


# act on replicas w/ a bad status
for table in $tables; do
    echo " > table replication in need of repair: $table"
    if [[ $RESTART == "true" ]]; then
      echo " sql: SYSTEM RESTART REPLICA ON CLUSTER simple ctl_api.$table;"
      kubectl --namespace=clickhouse exec -i $pod -- \
        clickhouse client -d ctl_api --distributed_ddl_task_timeout=3600 --progress -q "SYSTEM RESTART REPLICA ON CLUSTER simple ctl_api.$table;"
      sleep 3
    else
      echo " sql: SYSTEM RESTORE REPLICA ON CLUSTER simple ctl_api.$table;"
    fi
done

outputs=$(echo "$tables" | jq -R -s -c 'split("\n") | map(select(length > 0)) | {repaired_tables: .}')
echo $outputs >> $NUON_ACTIONS_OUTPUT_FILEPATH
