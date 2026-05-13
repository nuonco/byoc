#!/usr/bin/env bash

# Lists RDS snapshots in the current AWS account along with creation time,
# encryption status, and age in days. Useful for spotting stale unencrypted
# snapshots left over from a migration to encrypted snapshots.

set -e
set -o pipefail
set -u

export AWS_PAGER=""

echo "Listing RDS snapshots"
echo ""

SNAPSHOTS=$(aws rds describe-db-snapshots \
    --query "DBSnapshots[].[DBSnapshotIdentifier,SnapshotCreateTime,Encrypted,Engine,Status,AllocatedStorage]" \
    --output text)

if [ -z "$SNAPSHOTS" ]; then
    echo "No snapshots found."
    exit 0
fi

now_epoch=$(date -u +%s)

printf "%-60s  %-25s  %-9s  %-12s  %-12s  %-7s  %s\n" \
    "SNAPSHOT_ID" "CREATED" "ENCRYPTED" "ENGINE" "STATUS" "SIZE_GB" "AGE_DAYS"
printf "%s\n" "--------------------------------------------------------------------------------------------------------------------------------------------------"

while IFS=$'\t' read -r snapshot_id created encrypted engine status size; do
    [ -z "$snapshot_id" ] && continue

    # SnapshotCreateTime looks like 2023-12-01T10:30:45.000Z or 2023-12-01T10:30:45+00:00
    created_clean=$(echo "$created" | sed 's/\.[0-9]*Z$/Z/' | sed 's/+00:00$/Z/')
    if created_epoch=$(date -u -d "$created_clean" +%s 2>/dev/null); then
        :
    elif created_epoch=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$created_clean" +%s 2>/dev/null); then
        :
    else
        created_epoch=""
    fi

    if [ -n "$created_epoch" ]; then
        age_days=$(( (now_epoch - created_epoch) / 86400 ))
    else
        age_days="?"
    fi

    printf "%-60s  %-25s  %-9s  %-12s  %-12s  %-7s  %s\n" \
        "$snapshot_id" "$created_clean" "$encrypted" "$engine" "$status" "$size" "$age_days"
done <<< "$SNAPSHOTS" | sort -k2
