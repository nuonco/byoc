#!/usr/bin/env sh

# Cluster check 4/4 — "Is the shared wildcard TLS cert issued?"
# Step of the ctl_api_api_health_probe runbook. The https endpoints (public,
# runner, auth) share one wildcard ACM cert; until it is ISSUED their ALBs can't
# terminate TLS and won't come up. Needs AWS read perms (run under -provision).
# Does NOT use set -e.
#
# Required env:
#   CERT_ARN  the wildcard public-domain certificate ARN

set -u
export AWS_PAGER=""

CERT_ARN="${CERT_ARN:-}"

echo "==================================================================="
echo " Is the shared wildcard TLS cert issued?"
echo "==================================================================="

if ! command -v aws >/dev/null 2>&1; then
  echo "  aws CLI not available — cannot inspect ACM. (Is this running under -provision?)"
  echo "probe complete."
  exit 0
fi

if [ -z "$CERT_ARN" ]; then
  echo "  CERT_ARN not provided — nothing to check."
  echo "probe complete."
  exit 0
fi

echo "cert: ${CERT_ARN}"
st=$(aws acm describe-certificate --certificate-arn "$CERT_ARN" \
  --query 'Certificate.Status' --output text 2>&1)
echo "  status: ${st}"
case "$st" in
  ISSUED) echo "  -> OK: https endpoints can terminate TLS." ;;
  PENDING_VALIDATION) echo "  -> NOT validated yet: DNS validation records likely missing — https ALBs will not come up." ;;
  *) echo "  -> unexpected status; inspect the cert (validation records / ARN)." ;;
esac

echo ""
echo "  Note: this only gates the https endpoints (public/runner/auth). The admin"
echo "        endpoint is plain http and does not depend on this cert."
echo ""
echo "probe complete."
