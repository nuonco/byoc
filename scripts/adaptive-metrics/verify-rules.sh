#!/usr/bin/env bash
#
# Verify Grafana Cloud Adaptive Metrics rules are applied and working.
#
# Usage:
#   GC_PROM_URL=https://prometheus-prod-XX.grafana.net \
#   GC_INSTANCE_ID=123456 \
#   GC_API_TOKEN=glc_... \
#   ./verify-rules.sh
#
# GC_INSTANCE_ID is the Prometheus/Mimir instance ID (the basicAuthUser
# from the grafanacloud-prom datasource), NOT the Grafana Cloud stack ID.
# The token must also have metrics:read scope for the series-count queries.

set -euo pipefail

: "${GC_PROM_URL:?GC_PROM_URL must be set}"
: "${GC_INSTANCE_ID:?GC_INSTANCE_ID must be set}"
: "${GC_API_TOKEN:?GC_API_TOKEN must be set}"

AUTH="${GC_INSTANCE_ID}:${GC_API_TOKEN}"
PASS=0
FAIL=0

check() {
  local desc="$1" result="$2"
  if [ "$result" = "PASS" ]; then
    echo "  ✓ ${desc}"
    PASS=$((PASS + 1))
  else
    echo "  ✗ ${desc}"
    FAIL=$((FAIL + 1))
  fi
}

echo "==> Listing current Adaptive Metrics rules..."
RULES=$(curl -sf -u "$AUTH" "${GC_PROM_URL}/aggregations/rules")
echo "$RULES" | python3 -m json.tool

echo ""
echo "==> Checking gorm_operation drop rule..."
HAS_GORM=$(echo "$RULES" | python3 -c "
import json, sys
rules = json.load(sys.stdin)
for r in rules:
    if r.get('metric') == 'gorm_operation' and r.get('match_type') == 'prefix' and r.get('drop') == True:
        print('PASS'); break
else:
    print('FAIL')
")
check "gorm_operation prefix drop rule present" "$HAS_GORM"

echo ""
echo "==> Checking db_span_* aggregation rules..."

# db_span_calls_total: drop collector_instance_id + db_sql_table
HAS_CALLS=$(echo "$RULES" | python3 -c "
import json, sys
rules = json.load(sys.stdin)
for r in rules:
    if r.get('metric') == 'db_span_calls_total' and r.get('match_type', 'exact') == 'exact':
        dl = sorted(r.get('drop_labels', []))
        if dl == ['collector_instance_id', 'db_sql_table'] and 'sum:counter' in r.get('aggregations', []):
            print('PASS'); break
else:
    print('FAIL')
")
check "db_span_calls_total: drop collector_instance_id + db_sql_table" "$HAS_CALLS"

# db_span_duration_milliseconds_bucket: drop collector_instance_id + db_sql_table
HAS_BUCKET=$(echo "$RULES" | python3 -c "
import json, sys
rules = json.load(sys.stdin)
for r in rules:
    if r.get('metric') == 'db_span_duration_milliseconds_bucket' and r.get('match_type', 'exact') == 'exact':
        dl = sorted(r.get('drop_labels', []))
        if dl == ['collector_instance_id', 'db_sql_table'] and 'sum:counter' in r.get('aggregations', []):
            print('PASS'); break
else:
    print('FAIL')
")
check "db_span_duration_milliseconds_bucket: drop collector_instance_id + db_sql_table" "$HAS_BUCKET"

# db_span_duration_milliseconds_count: drop collector_instance_id only
HAS_COUNT=$(echo "$RULES" | python3 -c "
import json, sys
rules = json.load(sys.stdin)
for r in rules:
    if r.get('metric') == 'db_span_duration_milliseconds_count' and r.get('match_type', 'exact') == 'exact':
        dl = r.get('drop_labels', [])
        if dl == ['collector_instance_id'] and 'sum:counter' in r.get('aggregations', []):
            print('PASS'); break
else:
    print('FAIL')
")
check "db_span_duration_milliseconds_count: drop collector_instance_id only (keep db_sql_table)" "$HAS_COUNT"

# db_span_duration_milliseconds_sum: drop collector_instance_id only
HAS_SUM=$(echo "$RULES" | python3 -c "
import json, sys
rules = json.load(sys.stdin)
for r in rules:
    if r.get('metric') == 'db_span_duration_milliseconds_sum' and r.get('match_type', 'exact') == 'exact':
        dl = r.get('drop_labels', [])
        if dl == ['collector_instance_id'] and 'sum:counter' in r.get('aggregations', []):
            print('PASS'); break
else:
    print('FAIL')
")
check "db_span_duration_milliseconds_sum: drop collector_instance_id only (keep db_sql_table)" "$HAS_SUM"

echo ""
echo "==> Querying for gorm_operation series (should be 0 after drop rule)..."
SERIES_COUNT=$(curl -sf -u "$AUTH" \
  "${GC_PROM_URL}/api/prom/api/v1/query?query=count(%7B__name__%3D~%22gorm_operation.*%22%7D)" 2>/dev/null || echo '{"status":"error","data":{"result":[]}}')

echo "$SERIES_COUNT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
results = data.get('data', {}).get('result', [])
if not results:
    print('  ✓ No gorm_operation series found (drop rule working)')
else:
    count = sum(float(r['value'][1]) for r in results)
    if count == 0:
        print('  ✓ No gorm_operation series found (drop rule working)')
    else:
        print(f'  ⚠  Found {count:.0f} gorm_operation series (may not have taken effect yet, wait ~5-10 min)')
"

echo ""
echo "==> Querying for db_span metrics..."
SPAN_COUNT=$(curl -sf -u "$AUTH" \
  "${GC_PROM_URL}/api/prom/api/v1/query?query=count(%7B__name__%3D~%22db_span_.*%22%7D)" 2>/dev/null || echo '{"status":"error","data":{"result":[]}}')

echo "$SPAN_COUNT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
results = data.get('data', {}).get('result', [])
if results:
    count = sum(float(r['value'][1]) for r in results)
    print(f'  ✓ Found {count:.0f} db_span series')
else:
    print('  ⚠  No db_span series found')
"

echo ""
echo "==> Checking collector_instance_id aggregation status..."
echo "  (Rules take ~5-10 min to take effect. Until then, old series may still show.)"
for metric in db_span_calls_total db_span_duration_milliseconds_bucket db_span_duration_milliseconds_count db_span_duration_milliseconds_sum; do
  RESULT=$(curl -sf -u "$AUTH" \
    "${GC_PROM_URL}/api/prom/api/v1/query?query=${metric}" 2>/dev/null || echo '{}')
  echo "$RESULT" | python3 -c "
import json, sys
metric = '$metric'
data = json.load(sys.stdin)
results = data.get('data', {}).get('result', [])
if not results:
    print(f'  {metric}: no data yet')
else:
    ci_values = set()
    for r in results:
        ci = r['metric'].get('collector_instance_id', '<missing>')
        ci_values.add(ci)
    if '<aggregated>' in ci_values:
        print(f'  ✓ {metric}: collector_instance_id aggregated ({len(results)} series)')
    elif len(ci_values) <= 1:
        print(f'  ~ {metric}: single collector_instance_id ({len(results)} series)')
    else:
        print(f'  ⚠  {metric}: still {len(ci_values)} collector_instance_id values ({len(results)} series) - rules may not have taken effect yet')
" 2>/dev/null || echo "  $metric: query error"
done

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ] || exit 1
