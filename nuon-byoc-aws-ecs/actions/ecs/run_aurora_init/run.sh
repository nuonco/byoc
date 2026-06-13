#!/usr/bin/env bash
set -euo pipefail
# SUBNETS is rendered as a Terraform-style list literal (["sn-a","sn-b"]); normalize for the AWS CLI.
SUBNETS_CSV=$(echo "$SUBNETS" | tr -d '[]" ' | tr ',' ',')
NET="awsvpcConfiguration={subnets=[$SUBNETS_CSV],securityGroups=[$SG],assignPublicIp=DISABLED}"

TASK_ARN=$(aws ecs run-task --region "$REGION" --cluster "$CLUSTER" \
  --task-definition "$TASK_DEF" --launch-type FARGATE \
  --network-configuration "$NET" \
  --query 'tasks[0].taskArn' --output text)
echo "Started: $TASK_ARN"

aws ecs wait tasks-stopped --region "$REGION" --cluster "$CLUSTER" --tasks "$TASK_ARN"

EXIT_CODE=$(aws ecs describe-tasks --region "$REGION" --cluster "$CLUSTER" --tasks "$TASK_ARN" \
  --query 'tasks[0].containers[?lastStatus==`STOPPED`].exitCode' --output text | tr '\t' '\n' | sort -u)
echo "Exit codes: $EXIT_CODE"
[[ "$EXIT_CODE" == "0" ]] || exit 1
