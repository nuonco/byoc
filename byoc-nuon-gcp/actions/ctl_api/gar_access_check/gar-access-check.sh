#!/usr/bin/env bash
set -euo pipefail

POD="${POD_NAME:-gar-access-check}"

cleanup() { kubectl delete pod "$POD" -n "$POD_NS" --ignore-not-found --wait=false >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "[gar-access-check] (re)creating pod $POD in ns=$POD_NS as serviceAccount=$POD_SA"
kubectl delete pod "$POD" -n "$POD_NS" --ignore-not-found >/dev/null 2>&1 || true

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: $POD
  namespace: $POD_NS
spec:
  serviceAccountName: $POD_SA
  restartPolicy: Never
  containers:
    - name: check
      image: google/cloud-sdk:slim
      command: ["sleep", "600"]
EOF

echo "[gar-access-check] waiting for pod to be ready"
kubectl wait --for=condition=Ready "pod/$POD" -n "$POD_NS" --timeout=180s

echo "[gar-access-check] running check as the ctl-api identity"
kubectl exec -i -n "$POD_NS" "$POD" -- bash -s \
  "$VENDOR_SA" "$GAR_HOST" "$GAR_PROJECT" "$GAR_REPO" "$GAR_IMAGES" <<'POD_SCRIPT'
set -u
VENDOR_SA="$1"; GAR_HOST="$2"; GAR_PROJECT="$3"; GAR_REPO="$4"; GAR_IMAGES="$5"

echo "  identity (must be in the vendor's customer_principals):"
SELF=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email || true)
echo "    ${SELF:-<none: pod has no GCP Workload Identity>}"

echo "  impersonating $VENDOR_SA"
if TOKEN=$(gcloud auth print-access-token \
    --impersonate-service-account="$VENDOR_SA" \
    --scopes=https://www.googleapis.com/auth/cloud-platform 2>/tmp/err); then
  echo "    IMPERSONATION OK"
else
  echo "    IMPERSONATION FAILED:"; sed 's/^/      /' /tmp/err
  echo "    => vendor must add  serviceAccount:${SELF}  to customer_principals"
  exit 1
fi

IFS=',' read -ra IMGS <<< "$GAR_IMAGES"
FIRST=$(echo "${IMGS[0]}" | tr -d ' ')
echo "  negative control: unauthenticated tags list for ${GAR_REPO}/${FIRST}"
NOAUTH=$(curl -s -o /dev/null -w '%{http_code}' "https://${GAR_HOST}/v2/${GAR_PROJECT}/${GAR_REPO}/${FIRST}/tags/list")
echo "    HTTP ${NOAUTH} (expect 401/403 -- proves the endpoint actually enforces auth)"
[ "$NOAUTH" = "200" ] && echo "    WARNING: repo answers without a token; results below prove nothing about the SA."

FAIL=0
for raw in "${IMGS[@]}"; do
  IMG=$(echo "$raw" | tr -d ' ')
  [ -z "$IMG" ] && continue
  REF="${GAR_HOST}/v2/${GAR_PROJECT}/${GAR_REPO}/${IMG}"
  echo "  ${GAR_REPO}/${IMG}:"
  CODE=$(curl -s -o /tmp/body -w '%{http_code}' -H "Authorization: Bearer $TOKEN" "https://${REF}/tags/list")
  case "$CODE" in
    200)     : ;;
    401|403) echo "    DENIED (HTTP ${CODE}) -- lacks roles/artifactregistry.reader on ${GAR_REPO}"; FAIL=1; continue ;;
    404)     echo "    NOT FOUND (HTTP ${CODE}) -- check project/repo/image"; FAIL=1; continue ;;
    *)       echo "    UNEXPECTED (HTTP ${CODE}):"; head -c 200 /tmp/body; echo; FAIL=1; continue ;;
  esac
  if tr -d ' \n\t' < /tmp/body | grep -q '"tags":\[[^]]'; then
    python3 -c 'import json;print("\n".join("    - "+t for t in (json.load(open("/tmp/body")).get("tags") or [])))' 2>/dev/null \
      || tr ',' '\n' < /tmp/body | sed -n 's/.*"\([^"]*\)".*/    - \1/p'
    echo "    READER OK"
  else
    echo "    no tags returned -- image may not exist (tags/list is repo-scoped); verify ${IMG}"
    echo "    raw: $(cat /tmp/body)"
    FAIL=1
  fi
done

echo
if [ "$FAIL" -ne 0 ]; then echo "  RESULT: one or more images failed"; exit 1; fi
echo "  RESULT: all images readable"
POD_SCRIPT

echo "[gar-access-check] done"
