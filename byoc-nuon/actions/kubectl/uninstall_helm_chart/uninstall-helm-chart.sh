#!/usr/bin/env sh
apk add --no-cache helm
export HELM_DRIVER=configmap
helm uninstall $CHART_NAME --namespace $NAMESPACE
