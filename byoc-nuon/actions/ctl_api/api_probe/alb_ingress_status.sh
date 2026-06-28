#!/usr/bin/env sh

# Cluster check 1/4 — "Are ALBs being built for the ingresses at all?"
# Step of the ctl_api_api_health_probe runbook. Lists every ctl-api ingress and
# whether it has an ALB address yet, plus its FailedBuildModel event count.
# Read-only, kubectl only (no AWS role). Does NOT use set -e.

set -u

NS="${NAMESPACE:-ctl-api}"

echo "==================================================================="
echo " Are ALBs being built for the ${NS} ingresses at all?"
echo "==================================================================="
for ing in $(kubectl get -n "$NS" ingress -o name 2>/dev/null); do
  alb=$(kubectl get -n "$NS" "$ing" -o jsonpath='{.status.loadBalancer.ingress[*].hostname}' 2>/dev/null)
  fbm=$(kubectl describe -n "$NS" "$ing" 2>/dev/null | grep -c "FailedBuildModel")
  echo "  ${ing}: alb=[${alb:-<none>}] FailedBuildModel_events=${fbm}"
done
echo ""
echo "  Interpreting:"
echo "    * alb=<none> + FailedBuildModel>0 on EVERY ingress => controller-wide failure;"
echo "      the controller can't build any ALB. Continue to the controller + IRSA steps."
echo "    * alb=<none> on just ONE ingress => endpoint-specific; check that endpoint's probe step."
echo "    * alb set on all => ALBs are built; the problem (if any) is downstream (DNS / the service)."
echo ""
echo "probe complete."
