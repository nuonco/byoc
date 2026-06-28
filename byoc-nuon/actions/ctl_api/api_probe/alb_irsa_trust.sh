#!/usr/bin/env sh

# Cluster check 3/4 — "Can the controller actually assume its role?"
# Step of the ctl_api_api_health_probe runbook. Compares the cluster OIDC issuer,
# the registered IAM OIDC providers, and the alb-controller role's trust policy.
# Re-derives the controller pod / role / SA itself (steps are independent runs).
# Needs AWS read perms (run under -provision). Does NOT use set -e.

set -u
export AWS_PAGER=""

echo "==================================================================="
echo " Can the controller actually assume its role?"
echo "==================================================================="

if ! command -v aws >/dev/null 2>&1; then
  echo "  aws CLI not available — cannot inspect IAM/EKS. (Is this running under -provision?)"
  echo "probe complete."
  exit 0
fi

# re-derive the controller pod, its SA, and the role it assumes (this step is a
# separate process from the controller step, so nothing is shared).
lbc_ns=$(kubectl get pods -A 2>/dev/null | grep -i "aws-load-balancer-controller" | awk '{print $1}' | head -1)
lbc_pod=""; lbc_sa=""; role_arn=""
if [ -n "$lbc_ns" ]; then
  lbc_pod=$(kubectl get -n "$lbc_ns" pods -o name 2>/dev/null | grep -i load-balancer | head -1)
  if [ -n "$lbc_pod" ]; then
    lbc_sa=$(kubectl get -n "$lbc_ns" "$lbc_pod" -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)
    role_arn=$(kubectl get -n "$lbc_ns" "$lbc_pod" \
      -o jsonpath='{range .spec.containers[0].env[*]}{.name}={.value}{"\n"}{end}' 2>/dev/null \
      | awk -F= '/^AWS_ROLE_ARN=/{print $2}')
  fi
fi
echo "role the controller assumes = [${role_arn:-<unknown>}]"
role_name=$(echo "$role_arn" | sed 's#.*role/##')

echo ""
echo "--- EKS cluster OIDC issuer(s) ---"
for c in $(aws eks list-clusters --query 'clusters[]' --output text 2>&1); do
  iss=$(aws eks describe-cluster --name "$c" --query 'cluster.identity.oidc.issuer' --output text 2>&1)
  echo "  cluster ${c}: ${iss}"
done

echo ""
echo "--- registered IAM OIDC identity providers ---"
aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[].Arn' --output text 2>&1 \
  | tr '\t' '\n' | sed 's/^/  /' || true

echo ""
echo "--- alb-controller role trust policy ---"
if [ -n "$role_name" ]; then
  aws iam get-role --role-name "$role_name" --query 'Role.AssumeRolePolicyDocument' --output json 2>&1
else
  echo "  (could not determine role name from pod env)"
fi

echo ""
echo "  Interpreting:"
echo "    * cluster OIDC issuer has NO matching IAM OIDC provider above => provider missing (root cause A)."
echo "    * provider exists but trust policy Principal.Federated / <issuer>:aud (sts.amazonaws.com) /"
echo "      <issuer>:sub (system:serviceaccount:${lbc_ns:-?}:${lbc_sa:-?}) don't match => fix trust policy (B)."
echo "    * a 403 ALSO happens if the role was DELETED — AWS returns the same"
echo "      'Not authorized to perform sts:AssumeRoleWithWebIdentity' whether the trust mismatches OR the"
echo "      role is absent, so confirm the role above actually exists."
echo "    * fix lives in the install/runner IRSA + OIDC infra, not the byoc-nuon app components."
echo ""
echo "probe complete."
