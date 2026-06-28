#!/usr/bin/env sh

# Generic, env-driven health probe for a single ctl-api HTTP endpoint. One of
# the per-endpoint steps of the ctl_api_api_health_probe runbook; the shared
# cluster-wide ALB/IRSA checks live in the alb_* / acm_cert steps (run once).
#
# Funnels: enablement -> reachability -> DNS -> ingress/ALB. Read-only,
# kubectl/curl only (no AWS role). Does NOT use set -e — every check runs and
# reports independently.
#
# Required env:
#   NAMESPACE     k8s namespace of the ingress (e.g. ctl-api)
#   INGRESS_NAME  ingress object name (e.g. ctl-api-public)
#   HOSTNAME      full hostname (e.g. api.<public_domain>)
#   ZONE          public | internal  (which Route53 zone the record should live in)
#   SCHEME        http | https
#   HEALTH_PATH   path to curl (e.g. /readyz)
# Optional env:
#   ENABLE        "true"|"false" — if false, the endpoint is intentionally not
#                 deployed and absence is expected (gated endpoints). Default true.

set -u

NAMESPACE="${NAMESPACE:?NAMESPACE is required}"
INGRESS_NAME="${INGRESS_NAME:?INGRESS_NAME is required}"
HOSTNAME="${HOSTNAME:?HOSTNAME is required}"
ZONE="${ZONE:-public}"
SCHEME="${SCHEME:-https}"
HEALTH_PATH="${HEALTH_PATH:-/readyz}"
ENABLE="${ENABLE:-true}"

echo "==================================================================="
echo " endpoint probe: ${INGRESS_NAME}  (${SCHEME}://${HOSTNAME}${HEALTH_PATH})"
echo " zone=${ZONE} namespace=${NAMESPACE}"
echo "==================================================================="

if [ "$ENABLE" = "false" ]; then
  echo ""
  echo "ENABLE=false — this endpoint is intentionally disabled for this install."
  echo "A missing ingress / NXDOMAIN here is EXPECTED, not a fault. Nothing to debug."
  echo "probe complete."
  exit 0
fi

# ── 1. reachability ──────────────────────────────────────────────────────────
echo ""
echo "--- 1. reachability (curl ${SCHEME}://${HOSTNAME}${HEALTH_PATH}) ---"
rc=0
code=$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' \
  "${SCHEME}://${HOSTNAME}${HEALTH_PATH}") || rc=$?
echo "curl exit=${rc} http_code=${code}"
if [ "$rc" -eq 0 ] && [ "${code:-0}" -ge 200 ] && [ "${code:-0}" -lt 500 ]; then
  echo "  -> REACHABLE (2xx-4xx; 401/403 just means up-but-unauthed). Endpoint is serving."
else
  case "$rc" in
    6)  echo "  -> exit 6: DNS does not resolve — see steps 2-3 (record missing / ALB not built)" ;;
    7)  echo "  -> exit 7: connection refused (resolves, but nothing listening yet)" ;;
    28) echo "  -> exit 28: timeout (resolves, but no/slow response — ALB still provisioning)" ;;
    3)  echo "  -> exit 3: malformed URL (check HOSTNAME/SCHEME)" ;;
    0)  echo "  -> HTTP ${code} (5xx) — reached the ALB/pod but the service is erroring" ;;
    *)  echo "  -> curl failed (exit ${rc})" ;;
  esac
fi

# ── 2. DNS ───────────────────────────────────────────────────────────────────
echo ""
echo "--- 2. DNS resolution (expected in the ${ZONE} Route53 zone) ---"
getent hosts "$HOSTNAME" || echo "  getent: NO resolution for ${HOSTNAME}"
if command -v nslookup >/dev/null 2>&1; then
  nslookup "$HOSTNAME" 2>&1 | sed 's/^/  /' || true
fi
if [ "$ZONE" = "internal" ]; then
  echo "  note: internal-zone records resolve only inside the VPC (this action runs in-cluster, so that's fine)."
fi

# ── 3. ingress / ALB ─────────────────────────────────────────────────────────
echo ""
echo "--- 3. ingress ${NAMESPACE}/${INGRESS_NAME} (ALB address + annotations) ---"
if ! kubectl get -n "$NAMESPACE" ingress "$INGRESS_NAME" >/dev/null 2>&1; then
  echo "  ingress ${INGRESS_NAME} NOT found — the helm release did not create it."
else
  alb=$(kubectl get -n "$NAMESPACE" ingress "$INGRESS_NAME" \
    -o jsonpath='{.status.loadBalancer.ingress[*].hostname}' 2>/dev/null)
  echo "  ALB address: [${alb:-<none>}]"
  echo "  external-dns hostname: $(kubectl get -n "$NAMESPACE" ingress "$INGRESS_NAME" -o jsonpath='{.metadata.annotations.external-dns\.alpha\.kubernetes\.io/hostname}' 2>&1)"
  echo "  ALB scheme: $(kubectl get -n "$NAMESPACE" ingress "$INGRESS_NAME" -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/scheme}' 2>&1) (expected: ${ZONE} => $( [ "$ZONE" = internal ] && echo internal || echo internet-facing ))"
  echo "  cert-arn: $(kubectl get -n "$NAMESPACE" ingress "$INGRESS_NAME" -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/certificate-arn}' 2>&1)"
  echo "  recent events:"
  kubectl describe -n "$NAMESPACE" ingress "$INGRESS_NAME" 2>&1 | sed -n '/Events:/,$p' | head -20 | sed 's/^/    /'
  if [ -z "$alb" ]; then
    echo ""
    echo "  >> No ALB address. The ingress exists but no load balancer was built."
    echo "     This is almost always a CLUSTER-WIDE problem, not this endpoint —"
    echo "     check the cluster steps (ALB ingress status / controller / IRSA trust / cert)."
  fi
fi

echo ""
echo "probe complete."
