#!/usr/bin/env bash
set -euo pipefail
TASK_ARN=$(aws ecs list-tasks --region "$REGION" --cluster "$CLUSTER" --service-name "$SERVICE" \
  --query 'taskArns[0]' --output text)
[[ "$TASK_ARN" != "None" ]] || { echo "no running tasks for $SERVICE"; exit 1; }
echo "==> exec into $TASK_ARN"
aws ecs execute-command --region "$REGION" --cluster "$CLUSTER" --task "$TASK_ARN" --interactive --command "$COMMAND"
