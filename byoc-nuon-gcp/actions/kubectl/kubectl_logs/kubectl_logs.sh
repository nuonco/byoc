#!/usr/bin/env sh
kubectl logs -n $NAMESPACE --all-containers=true -l app.kubernetes.io/name=ctl-api-api
