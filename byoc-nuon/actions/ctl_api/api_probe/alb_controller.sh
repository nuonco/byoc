#!/usr/bin/env sh

# Cluster check 2/4 — "Is the LB controller running and is its IRSA actually wired?"
# Step of the ctl_api_api_health_probe runbook. Inspects the AWS Load Balancer
# Controller pod, its ServiceAccount role-arn annotation, the injected IRSA env
# (AWS_ROLE_ARN / token path), and its logs for credential errors.
# Read-only, kubectl only (no AWS role). Does NOT use set -e.

set -u

echo "==================================================================="
echo " Is the LB controller running and is its IRSA actually wired?"
echo "==================================================================="
lbc_ns=$(kubectl get pods -A 2>/dev/null | grep -i "aws-load-balancer-controller" | awk '{print $1}' | head -1)
if [ -z "$lbc_ns" ]; then
  echo "  controller pod NOT found cluster-wide (grep aws-load-balancer-controller)."
  echo "  Try: kubectl get pods -A | grep -i load-balancer"
  echo ""
  echo "probe complete."
  exit 0
fi

echo "namespace: ${lbc_ns}"
kubectl get -n "$lbc_ns" pods 2>&1 | grep -iE "NAME|load-balancer" || true

lbc_pod=$(kubectl get -n "$lbc_ns" pods -o name 2>/dev/null | grep -i load-balancer | head -1)
if [ -n "$lbc_pod" ]; then
  lbc_sa=$(kubectl get -n "$lbc_ns" "$lbc_pod" -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)
  echo ""
  echo "serviceAccountName: ${lbc_sa:-<unknown>}"
  if [ -n "${lbc_sa:-}" ]; then
    echo "  SA role-arn annotation: $(kubectl get -n "$lbc_ns" sa "$lbc_sa" -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>&1)"
  fi

  echo ""
  echo "--- injected IRSA env (role + token path) ---"
  kubectl get -n "$lbc_ns" "$lbc_pod" \
    -o jsonpath='{range .spec.containers[0].env[*]}{.name}={.value}{"\n"}{end}' 2>/dev/null \
    | grep -iE "AWS_ROLE_ARN|AWS_WEB_IDENTITY_TOKEN_FILE|AWS_STS_REGIONAL" \
    || echo "  (no AWS_ROLE_ARN env — IRSA webhook injected nothing; SA annotation likely missing)"

  echo ""
  echo "  => the role's trust policy MUST allow sub: system:serviceaccount:${lbc_ns}:${lbc_sa:-<unknown>}"

  echo ""
  echo "--- controller logs: AssumeRoleWithWebIdentity / credential errors (last 200) ---"
  kubectl logs -n "$lbc_ns" "$lbc_pod" --tail=200 2>&1 \
    | grep -iE "AssumeRoleWithWebIdentity|credential|WebIdentity|AccessDenied|oidc" | tail -30 \
    || echo "  (no matching log lines)"
fi

echo ""
echo "  Interpreting:"
echo "    * no AWS_ROLE_ARN env      => SA annotation missing; the IRSA webhook injected nothing."
echo "    * env present + AssumeRoleWithWebIdentity 403 in logs => env is fine but STS rejects the"
echo "      assume; the role trust policy / OIDC provider is the problem (see the IRSA trust step)."
echo ""
echo "probe complete."
