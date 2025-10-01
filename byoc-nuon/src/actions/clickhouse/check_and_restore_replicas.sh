#!/usr/bin/env sh

outputs='{}'
echo "getting a pod"
pod=`kubectl -n clickhouse get pods | grep installation | cut -d ' ' -f 1 | tail -n 1`

echo "listing tables"
kubectl --namespace=clickhouse exec -i $pod -- clickhouse client -d ctl_api -q "SELECT table FROM system.replicas WHERE database = 'ctl_api';"

# replica statuses
echo "getting replica statuses"
rows=`kubectl --namespace=clickhouse exec -i $pod -- clickhouse client -d ctl_api -q "SELECT * FROM system.replicas WHERE database = 'ctl_api' FORMAT JSONEachRow"`

for row in $rows; do
  echo $row | jq -r '" > \(.is_readonly) \(.database) \(.table)"'
done

tables=`echo "$rows" | jq -s 'map({(.table): .}) | add'`

# persist tables to outputs
outputs=`jq -n --argjson outputs "$outputs" --argjson tables "$tables" '$outputs + {tables: $tables}'`

# act on replicas w/ a bad status
for row in $rows; do
  is_readonly=`echo $row | jq -r '.is_readonly'`
  table=`echo $row | jq '.table'`
  if [[ "$is_readonly" == "1" ]]; then
    echo " > table replication in need of repair: "$table
    kubectl --namespace=clickhouse exec -i $pod -- clickhouse client -d ctl_api -q "system restore replica on cluster simple ctl_api.$table;"
    echo " > table replication restore - taking a small nap "$table
    sleep 1
  else
    echo " > no action required: "$table
  fi
done

echo $outputs >> $NUON_ACTIONS_OUTPUT_FILEPATH
