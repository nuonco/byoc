Runs every action that populates a section of the install README, so the rendered page reflects current state. Use this after a deploy, or any time the README looks stale.

**Actions**

| Action | Populates |
|---|---|
| `api_status` | API status badge, version/git labels, healthcheck indicators |
| `dashboard_status` | Dashboard status badge, version/git labels |
| `inspect_runners` | Runners section |
| `inspect_installs` | Installs section |
| `inspect_databases` | Databases section — Postgres (RDS) table |
| `ch_inspect` | Databases section — ClickHouse table |
| `inspect_apps` | Apps section |
| `inspect_orgs` | Orgs section |
| `healthcheck_temporal` | Temporal healthcheck indicator |
| `temporal_status` | Active Temporal workflows by namespace |
| `ctl_api_query_workflows_by_type` | Workflows table |
