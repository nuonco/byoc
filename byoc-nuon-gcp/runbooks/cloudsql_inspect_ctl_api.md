Inspects the **ctl-api (nuon)** Cloud SQL instance (`nuon-<install-id>`) and prints, in table format:

- a one-line summary: instance name, tier, and state
- the instance configuration: tier, edition, engine/version, maintenance version, state, storage type, allocated GB, storage auto-resize and limit, availability type, region, zone, private IP, backups / PITR / Query Insights flags, and database flags
- the most recent operations against the instance (last 10): backups, updates, restarts, and failovers with their status

Use this to size the instance, check storage auto-resize headroom, confirm backups and PITR are enabled, and see what recently changed on the instance before or after a control-plane incident.

> Query Insights must be enabled on the instance for query-level metrics in the GCP console. The runbook prints whether it is enabled; per-query breakdowns live under Cloud SQL → Query insights.
