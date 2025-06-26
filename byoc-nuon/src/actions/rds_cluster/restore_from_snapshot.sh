#!/usr/bin/env bash

# create an rds instance from an rds snapshot.

set -e
set -o pipefail
set -u

# always present
region="$REGION"
rds_db_subnet_group_name="$RDS_DB_SUBNET_GROUP_NAME"

# only necessary to create the rds cluster
snapshot="${DB_SNAPSHOT_ARN:-}"
identifier="$IDENTIFIER"

# always runs
snapshots=`aws --region $region rds describe-db-snapshots --filters "Name=db-instance-id,Values=nuon-$NUON_INSTALL_ID" | jq '.DBSnapshots' `
echo $snapshots |  jq -r '.[] | "\(.SnapshotCreateTime) \(.DBSnapshotArn)"'

# only runs if a snapshot is specified
if [[ "$snapshot" != "" ]]; then
  echo "creating rds instance from snapshot"
  echo " > db-instance-identifier: $identifier"
  echo " > db-snapshot-identifier: $snapshot"
  echo " > db-subnet-group-name:   $rds_db_subnet_group_name"
  aws rds restore-db-instance-from-db-snapshot \
      --db-instance-identifier "$identifier"   \
      --db-snapshot-identifier $snapshot       \
      --db-subnet-group-name "$rds_db_subnet_group_name" \
      --allocated-storage 100
fi
