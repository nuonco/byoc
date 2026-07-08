#!/usr/bin/env bash

set -e
set -o pipefail
set -u

# Best-effort analog of the AWS rds_aas breakdown: Cloud SQL has no Performance
# Insights API, so print the Query Insights config and a console deep link.
#
# Required env:
#   DB_INSTANCE_NAME  the Cloud SQL instance name (cloudsql_*.outputs.db_instance_name)
#   PROJECT_ID        the GCP project id
# Optional env:
#   DB_LABEL          human-friendly label used in the header (defaults to "database")

db_instance_name="$DB_INSTANCE_NAME"
project_id="$PROJECT_ID"
db_label="${DB_LABEL:-database}"

echo "==================================================================="
echo " Cloud SQL load breakdown (Query Insights): ${db_label}"
echo " instance: ${db_instance_name}"
echo "==================================================================="

instance_json=$(gcloud sql instances describe "$db_instance_name" \
  --project "$project_id" --format json)

insights_enabled=$(echo "$instance_json" | jq -r '.settings.insightsConfig.queryInsightsEnabled // false')

echo
echo "### Query Insights configuration"
echo "$instance_json" | jq '{
  QueryInsightsEnabled: (.settings.insightsConfig.queryInsightsEnabled // false),
  RecordApplicationTags: (.settings.insightsConfig.recordApplicationTags // false),
  RecordClientAddress: (.settings.insightsConfig.recordClientAddress // false),
  QueryStringLength: (.settings.insightsConfig.queryStringLength // null),
  QueryPlansPerMinute: (.settings.insightsConfig.queryPlansPerMinute // null)
}'

echo
if [ "$insights_enabled" != "true" ]; then
  echo "Query Insights is DISABLED on this instance."
  echo "Enable it to get the load-by-query / load-by-wait breakdown:"
  echo "  gcloud sql instances patch ${db_instance_name} --project ${project_id} --insights-config-query-insights-enabled"
  echo
fi

echo "### AAS analog — Query Insights (console-only for the per-dimension breakdown)"
echo "AWS 'AAS by wait / by query / by lock' maps to the Query Insights"
echo "'Database load' chart, which can be grouped by query, by wait event, by tag,"
echo "by client address, and by user. There is no gcloud/API surface for that"
echo "ranked breakdown, so open it in the console:"
echo
echo "  https://console.cloud.google.com/sql/instances/${db_instance_name}/insights?project=${project_id}"
echo
echo "### Programmatic access"
echo "Per-query aggregate metrics are available via Cloud Monitoring under the"
echo "metric prefix: cloudsql.googleapis.com/database/postgresql/insights/"
echo "(e.g. .../insights/perquery/latencies, .../insights/aggregate/latencies)."
