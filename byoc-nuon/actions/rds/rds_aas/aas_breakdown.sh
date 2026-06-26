#!/usr/bin/env bash

set -e
set -o pipefail
set -u

# Breaks down Average Active Sessions (AAS, the Performance Insights `db.load.avg`
# metric) over the last hour by a chosen dimension, and prints it as a ranked table.
#
# Required env:
#   DB_RESOURCE_ID  stable DbiResourceId (rds_cluster_*.outputs.db_instance_resource_id)
#   MODE            one of: waits | queries | locks
# Optional env:
#   DB_LABEL        human-friendly label used in the header (defaults to "database")
#   TOP_N           number of rows to show (defaults to 15)

db_resource_id="$DB_RESOURCE_ID"
mode="$MODE"
db_label="${DB_LABEL:-database}"
top_n="${TOP_N:-15}"

case "$mode" in
  waits)
    title="AAS by wait event"
    group='{"Group":"db.wait_event","Dimensions":["db.wait_event.name","db.wait_event.type"]}'
    dim_key="db.wait_event.name"
    type_filter=''
    key_header="WAIT_EVENT"
    key_width=40
    ;;
  queries)
    title="AAS by query (tokenized SQL)"
    group='{"Group":"db.sql_tokenized","Dimensions":["db.sql_tokenized.statement"]}'
    dim_key="db.sql_tokenized.statement"
    type_filter=''
    key_header="STATEMENT"
    key_width=90
    ;;
  locks)
    title="AAS by lock wait"
    group='{"Group":"db.wait_event","Dimensions":["db.wait_event.name","db.wait_event.type"]}'
    dim_key="db.wait_event.name"
    # only heavyweight Lock waits (db.wait_event.type == "Lock")
    type_filter='Lock'
    key_header="LOCK_WAIT_EVENT"
    key_width=40
    ;;
  *)
    echo >&2 "error: MODE must be one of waits|queries|locks, got '${mode}'"
    exit 1
    ;;
esac

now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
one_hour_ago=$(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
            || date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)

echo "### ${title} — ${db_label} (last hour)"

raw=$(aws pi describe-dimension-keys \
  --service-type RDS --identifier "$db_resource_id" \
  --metric db.load.avg \
  --start-time "$one_hour_ago" --end-time "$now" \
  --period-in-seconds 3600 \
  --group-by "$group" \
  --max-results 25 \
  --output json 2>&1) || {
    echo "could not fetch AAS dimension keys for ${db_resource_id}: ${raw}"
    exit 0
  }

FMT="%-5s %-9s %-8s %-${key_width}s\n"
printf "$FMT" RANK AAS %LOAD "$key_header"

echo "$raw" | jq -r \
  --arg dim_key "$dim_key" \
  --arg type_filter "$type_filter" \
  --argjson top_n "$top_n" '
    .Keys as $keys
    # grand total load across all returned keys, used to compute each row'\''s share
    | ([$keys[].Total] | add // 0) as $grand
    | $keys
    | map(select($type_filter == "" or (.Dimensions["db.wait_event.type"] // "") == $type_filter))
    | sort_by(-.Total)
    | .[:$top_n]
    | to_entries[]
    | [ (.key + 1),
        ((.value.Total * 100 | round) / 100),
        (if $grand > 0 then ((.value.Total / $grand) * 100 * 10 | round / 10) else 0 end),
        ( (.value.Dimensions[$dim_key]) // "unknown"
          | tostring | gsub("[\n\t]+"; " ") | gsub("  +"; " ") )
      ]
    | @tsv
  ' \
| while IFS=$'\t' read -r rank aas pct key; do
    # truncate long keys (e.g. SQL statements) to the column width
    if [ "${#key}" -gt "$key_width" ]; then
      key="${key:0:$((key_width - 1))}…"
    fi
    printf "$FMT" "$rank" "$aas" "${pct}%" "$key"
  done

# if nothing matched (e.g. no lock waits in the window), say so explicitly
count=$(echo "$raw" | jq -r --arg type_filter "$type_filter" '
  [.Keys[] | select($type_filter == "" or (.Dimensions["db.wait_event.type"] // "") == $type_filter)] | length')
if [ "$count" = "0" ]; then
  echo "(no ${mode} activity recorded in the window)"
fi
