#!/usr/bin/env bash

# Deletes the manual RDS snapshots listed in $SNAPSHOT_IDS (space or
# comma separated). Each ID is verified to exist before deletion so a
# typo fails loud instead of being silently ignored.

set -e
set -o pipefail
set -u

export AWS_PAGER=""

if [ -z "${SNAPSHOT_IDS:-}" ]; then
    echo "SNAPSHOT_IDS is empty — nothing to do"
    exit 1
fi

# normalize separators to whitespace
ids=$(echo "$SNAPSHOT_IDS" | tr ',' ' ')

echo "Snapshots queued for deletion:"
for id in $ids; do
    echo "  - $id"
done
echo ""

for id in $ids; do
    echo "Looking up $id ..."
    info=$(aws rds describe-db-snapshots \
        --db-snapshot-identifier "$id" \
        --snapshot-type manual \
        --query "DBSnapshots[0].[DBSnapshotIdentifier,SnapshotCreateTime,Encrypted,Status]" \
        --output text)

    if [ -z "$info" ] || [ "$info" = "None" ]; then
        echo "  not found as a manual snapshot — skipping"
        echo ""
        continue
    fi

    echo "  found: $info"
    echo "  deleting..."
    aws rds delete-db-snapshot --db-snapshot-identifier "$id" >/dev/null
    echo "  deleted $id"
    echo ""
done

echo "Cleanup complete."
