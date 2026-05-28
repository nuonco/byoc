#!/usr/bin/env sh
apk add --no-cache helm
export HELM_DRIVER=configmap
helm history $CHART_NAME -n $NAMESPACE
