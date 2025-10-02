#!/usr/bin/env bash

# triggers a runner ASG instance refresh for the install runner that corresponds to this BYOC Nuon Install

set -e
set -o pipefail
set -u

dry_run="${DRY_RUN:-false}"

# disable pager
export AWS_PAGER=""

# search for asg by install id in tag value.
# NOTE: future runners ASGs will have additional tags we can search by
echo 'searching for ASGs for this install'
asgs=`aws autoscaling describe-auto-scaling-groups --filters "Name=tag-value,Values=$NUON_INSTALL_ID" | jq '.AutoScalingGroups'`
count=`echo $asgs | jq length`

echo "Found $count ASGs for this Install"
echo $asgs | jq -r '.[] | "> \(.AutoScalingGroupName)\n\(.AutoScalingGroupARN)" '

if [[ "$dry_run" != "true" ]]; then
  echo 'executing instance-refresh'
  for name in `echo $asgs | jq -r ".[].AutoScalingGroupName"`; do
    echo "  > refreshing: $name"
    aws autoscaling start-instance-refresh --auto-scaling-group-name $name
  done
else
  echo '[dry-run] will not execute'
  for name in `echo $asgs | jq -r ".[].AutoScalingGroupName"`; do
    echo "aws autoscaling start-instance-refresh --auto-scaling-group-name $name"
  done
fi
