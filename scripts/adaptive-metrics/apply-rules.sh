#!/usr/bin/env bash
#
# Apply Grafana Cloud Adaptive Metrics rules.
#
# Fetches the current aggregation/drop rules from Grafana Cloud, merges them
# with the rules defined in rules.json (adding new rules, updating existing
# ones by metric name + match_type), and uploads the merged set back.
#
# Usage:
#   GC_PROM_URL=https://prometheus-prod-XX.grafana.net \
#   GC_INSTANCE_ID=123456 \
#   GC_API_TOKEN=glc_... \
#   ./apply-rules.sh [rules.json]
#
# GC_INSTANCE_ID is the Prometheus/Mimir instance ID (the basicAuthUser
# from the grafanacloud-prom datasource), NOT the Grafana Cloud stack ID.
#
# The API token must belong to a Grafana Cloud Access Policy with the
# `adaptive-metrics-rules:read` and `adaptive-metrics-rules:write` scopes.
#
# See: https://grafana.com/docs/grafana-cloud/observe-and-act/adaptive-telemetry/adaptive-metrics/manage-as-code/adaptive-metrics-api/

set -euo pipefail

RULES_FILE="${1:-$(dirname "$0")/rules.json}"

# --- validate env ---
: "${GC_PROM_URL:?GC_PROM_URL must be set (e.g. https://prometheus-prod-XX.grafana.net)}"
: "${GC_INSTANCE_ID:?GC_INSTANCE_ID must be set (Grafana Cloud numeric instance ID / tenant)}"
: "${GC_API_TOKEN:?GC_API_TOKEN must be set (Grafana Cloud Access Policy token with adaptive-metrics-rules:read/write scopes)}"

AUTH="${GC_INSTANCE_ID}:${GC_API_TOKEN}"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "==> Fetching current Adaptive Metrics rules from ${GC_PROM_URL}..."
curl -sf -u "$AUTH" -D "${TMPDIR}/headers.txt" -o "${TMPDIR}/current.json" \
  "${GC_PROM_URL}/aggregations/rules"

ETAG="If-Match: $(grep -i '^etag:' "${TMPDIR}/headers.txt" | tr -d '\r' | sed 's/^[Ee][Tt][Aa][Gg]:[[:space:]]*//i')"

if [ -z "$ETAG" ]; then
  echo "ERROR: No ETag header in response. Cannot safely update rules." >&2
  exit 1
fi

echo "   ETag: ${ETAG}"

# --- merge rules ---
# Use python3 to merge: add new rules from RULES_FILE, update existing ones
# (matched by metric + match_type), and preserve all other existing rules.
python3 - "$RULES_FILE" "${TMPDIR}/current.json" "${TMPDIR}/merged.json" << 'PY'
import json, sys

rules_file, current_file, merged_file = sys.argv[1:4]

with open(rules_file) as f:
    new_rules = json.load(f)

with open(current_file) as f:
    current_rules = json.load(f)

# Build a lookup of existing rules by (metric, match_type) key
def rule_key(r):
    return (r.get("metric", ""), r.get("match_type", "exact"))

existing = {rule_key(r): r for r in current_rules}

for new_rule in new_rules:
    key = rule_key(new_rule)
    if key in existing:
        existing[key].update(new_rule)
    else:
        current_rules.append(new_rule)
        existing[key] = new_rule

with open(merged_file, "w") as f:
    json.dump(current_rules, f, indent=2)

print(f"   Current rules: {len(current_rules) - len(new_rules) + len(set(rule_key(r) for r in new_rules) & set(existing.keys()))}")
print(f"   Rules to add/update: {len(new_rules)}")
print(f"   Total rules after merge: {len(current_rules)}")
PY

echo "==> Uploading merged rules..."
HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" \
  -X POST \
  -H "$ETAG" \
  -H "Content-Type: application/json" \
  --data-binary @"${TMPDIR}/merged.json" \
  -u "$AUTH" \
  "${GC_PROM_URL}/aggregations/rules")

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "204" ]; then
  echo "✓ Rules uploaded successfully (HTTP $HTTP_CODE)"
  echo "  Changes take effect within ~5-10 minutes."
else
  echo "ERROR: Upload failed with HTTP $HTTP_CODE" >&2
  exit 1
fi
