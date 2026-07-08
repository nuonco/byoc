Inspects the **ctl-api (nuon)** (`nuon-<install-id>`) and **Temporal** (`temporal-<install-id>`) Cloud SQL instances
and prints, for each, in table format:

- a one-line summary: instance name, tier, and state
- the instance configuration: tier, edition, engine/version, maintenance version, state, storage type, allocated GB,
  storage auto-resize and limit, availability type, region, zone, private IP, backups / PITR / Query Insights flags, and
  database flags
- the most recent operations against the instance (last 10): backups, updates, restarts, and failovers with their status
- OS-level metrics from Cloud Monitoring for the last hour at 60s resolution: CPU%, memory%, disk%, active
  connections, read / write / total IOPS, and network rx/tx (MB/s) — the Cloud SQL analog of the AWS `rds_inspect`
  Performance Insights OS-metric table

Each instance is followed by a **load breakdown (Query Insights)** section: whether Query Insights is enabled (and its
config), a deep link to the Query Insights dashboard, and the Cloud Monitoring metric prefix for programmatic access.
This is the Cloud SQL analog of the AWS `rds_aas` AAS-by-wait / by-query / by-lock breakdown; Cloud SQL has no
Performance Insights API, so the per-dimension ranking is console-only.

Use this to size the instances, check storage auto-resize headroom, confirm backups and PITR are enabled, see what
recently changed on an instance, and find what is driving database load before or after a control-plane or Temporal
incident.

> Query Insights must be enabled on the instance for query-level metrics in the GCP console. The runbook prints whether
> it is enabled; per-query breakdowns live under Cloud SQL → Query insights.
