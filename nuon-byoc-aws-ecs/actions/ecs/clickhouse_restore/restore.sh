#!/usr/bin/env bash
set -euo pipefail
[[ -n "$BACKUP_NAME" ]] || { echo "BACKUP_NAME is required"; exit 1; }

SUBNETS_CSV=$(echo "$SUBNETS" | tr -d '[]" ' | tr ',' ',')
NET="awsvpcConfiguration={subnets=[$SUBNETS_CSV],securityGroups=[$SG],assignPublicIp=DISABLED}"

# Override the container command at runtime.
OVERRIDES=$(cat <<EOF
{"containerOverrides":[{"name":"backup","command":["restore_remote","$BACKUP_NAME"]}]}
EOF
)

TASK_ARN=$(aws ecs run-task --region "$REGION" --cluster "$CLUSTER" \
  --task-definition "$TASK_FAMILY" --launch-type FARGATE \
  --network-configuration "$NET" \
  --overrides "$OVERRIDES" \
  --query 'tasks[0].taskArn' --output text)
echo "Started: $TASK_ARN"

aws ecs wait tasks-stopped --region "$REGION" --cluster "$CLUSTER" --tasks "$TASK_ARN"
EXIT_CODE=$(aws ecs describe-tasks --region "$REGION" --cluster "$CLUSTER" --tasks "$TASK_ARN" \
  --query 'tasks[0].containers[0].exitCode' --output text)
echo "Exit: $EXIT_CODE"
[[ "$EXIT_CODE" == "0" ]] || exit 1
