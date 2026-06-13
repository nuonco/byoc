#!/usr/bin/env sh
kubectl \
  --namespace $NAMESPACE \
  get pods \
  -o name | \
  xargs -n 1 \
  kubectl \
  delete \
  -n $NAMESPACE \
  --grace-period=0 \
  --force
