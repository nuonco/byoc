#!/usr/bin/env bash

# Script to find snapshots with a given prefix and rename them by appending creation timestamp
# Usage: ./rename_snapshots.sh <name_prefix>

set -e
set -o pipefail
set -u

prefix="$PREFIX"
echo "finding snapshots with prefix: $prefix"

export AWS_PAGER=""

# Get snapshots that match the prefix and are owned by the current account
SNAPSHOTS=$(aws rds describe-db-snapshots \
    --snapshot-type manual \
    --query "DBSnapshots[?starts_with(DBSnapshotIdentifier, '$prefix')].[DBSnapshotIdentifier,SnapshotCreateTime]" \
    --output text)

if [ -z "$SNAPSHOTS" ]; then
    echo "No snapshots found with prefix: $prefix"
    exit 0
fi

echo "Found snapshots:"
echo "$SNAPSHOTS"
echo ""

while IFS=$'\t' read -r snapshot_id start_time; do
    if [ -z "$snapshot_id" ] || [ -z "$start_time" ]; then
        continue
    fi

    echo "Processing RDS snapshot: $snapshot_id"
    echo "Creation time: $start_time"

    # Extract date and time from ISO format (2023-12-01T10:30:45.000Z)
    # Convert to format: YYYY-MM-DD-HH-MM-SS
    timestamp=$(echo "$start_time" | cut -d'T' -f1,2 | tr 'T' '_' | cut -d'.' -f1 | sed 's/://g' | sed 's/_\(..\)\(..\)\(..\)$/-\1-\2-\3/')

    # Create new name by appending timestamp
    new_name="${snapshot_id}-${timestamp}"

    echo "New name: $new_name"

    # Check if name already contains a timestamp (avoid double-renaming)
    if [[ "$snapshot_id" =~ \-[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "Snapshot already appears to have timestamp suffix, skipping..."
        echo ""
        continue
    fi

    # Copy the snapshot with the new name, then delete the old one
    echo "Creating snapshot copy with new name..."
    aws rds copy-db-snapshot \
        --source-db-snapshot-identifier "$snapshot_id" \
        --target-db-snapshot-identifier "$new_name"

    # Wait for the copy to complete
    echo "Waiting for snapshot copy to complete..."
    aws rds wait db-snapshot-completed \
        --db-snapshot-identifier "$new_name"

    # Delete the original snapshot
    echo "Deleting original snapshot..."
    aws rds delete-db-snapshot \
        --db-snapshot-identifier "$snapshot_id"

    echo "Successfully renamed to: $new_name"
    echo ""

done <<< "$SNAPSHOTS"

echo "Renaming complete!"
