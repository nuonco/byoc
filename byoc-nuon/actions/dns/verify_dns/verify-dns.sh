#!/usr/bin/env sh

# Verify that the public DNS delegation for an install's public domain is live:
# resolve the domain's NS records and compare them to the nameservers Nuon
# provisioned. A mismatch means the customer has not (yet) added the NS records
# at their registrar delegating the domain to this install.
#
# Queries a PUBLIC resolver (1.1.1.1 / 8.8.8.8) rather than the in-cluster
# resolver so the answer reflects the real public-internet view of the
# delegation, not a VPC / split-horizon resolver.
#
# Required env:
#   DOMAIN        the public domain (e.g. install.example.com)
#   EXPECTED_NS   space-separated expected nameservers (from sandbox outputs)

set -u

DOMAIN="${DOMAIN:-}"
EXPECTED_NS="${EXPECTED_NS:-}"

echo "==================================================================="
echo " dns delegation check: ${DOMAIN:-<unset>}"
echo "==================================================================="

if [ -z "$DOMAIN" ] || [ -z "$EXPECTED_NS" ]; then
  echo ""
  echo "SKIP: no public domain / nameservers provisioned yet."
  echo "The sandbox has not finished provisioning the DNS zone. Re-run once it has."
  exit 0
fi

norm() {
  # lowercase, strip trailing dot, one per line, sorted, deduped
  tr 'A-Z' 'a-z' | sed 's/\.$//' | sed '/^$/d' | sort -u
}

echo ""
echo "--- expected nameservers (provisioned by Nuon) ---"
expected=$(printf '%s\n' $EXPECTED_NS | norm)
echo "$expected" | sed 's/^/  /'

# ── query a public resolver for the live NS records ──────────────────────────
observed=""
resolver=""
for r in 1.1.1.1 8.8.8.8; do
  if command -v dig >/dev/null 2>&1; then
    out=$(dig +short NS "$DOMAIN" "@$r" 2>/dev/null)
  elif command -v nslookup >/dev/null 2>&1; then
    out=$(nslookup -type=ns "$DOMAIN" "$r" 2>/dev/null | sed -n 's/.*nameserver = //p')
  else
    echo ""
    echo "ERROR: neither dig nor nslookup is available in this environment."
    exit 1
  fi
  out=$(printf '%s\n' "$out" | norm)
  if [ -n "$out" ]; then
    observed="$out"
    resolver="$r"
    break
  fi
done

echo ""
echo "--- observed nameservers (public resolver ${resolver:-none}) ---"
if [ -z "$observed" ]; then
  echo "  <none — the domain does not resolve any NS records>"
else
  echo "$observed" | sed 's/^/  /'
fi

# ── compare ──────────────────────────────────────────────────────────────────
missing=""
for ns in $expected; do
  if ! printf '%s\n' $observed | grep -qxF "$ns"; then
    missing="$missing $ns"
  fi
done

echo ""
if [ -z "$observed" ]; then
  echo "RESULT: NOT DELEGATED"
  echo "  ${DOMAIN} resolves no NS records. The customer must add the NS records"
  echo "  above at their registrar (or parent DNS provider) delegating this domain."
  exit 0
fi
if [ -n "$missing" ]; then
  echo "RESULT: NOT DELEGATED (incomplete)"
  echo "  missing expected nameserver(s):$missing"
  echo "  The registrar delegation is partial/incorrect — the NS record set at the"
  echo "  registrar must contain every expected nameserver above."
  exit 0
fi

echo "RESULT: DELEGATED ✓"
echo "  ${DOMAIN} resolves to the expected nameservers. The delegation is live."
