#!/usr/bin/env bash
set -euo pipefail
for svc in $SERVICES; do
  echo "==> $svc"
  aws ecs update-service --region "$REGION" --cluster "$CLUSTER" --service "$svc" --force-new-deployment --query 'service.deployments[0].status' --output text
done
