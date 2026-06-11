# ClickHouse Backups Present Policy (terraform_module, component: clickhouse_cluster)
#
# The ClickHouse cluster stores control-plane telemetry and is protected by
# scheduled backups to S3. Shipping the cluster without those backup manifests
# would leave that data with no recovery path.
#
# Checks:
#   - if the ClickHouse installation is deployed, backup manifests must exist  (warn)
#
# Input: Terraform JSON plan (input.plan.resource_changes). The cluster and its
# backups are applied as kubectl_manifest resources.

package nuon

import future.keywords.contains
import future.keywords.if
import future.keywords.in

installation_present if {
	some rc in input.plan.resource_changes
	rc.type == "kubectl_manifest"
	contains(rc.address, "clickhouse_installation")
}

backup_manifests := [rc |
	some rc in input.plan.resource_changes
	rc.type == "kubectl_manifest"
	contains(lower(rc.address), "backup")
]

# ──────────────────────────────────────────────────────────────────────────────
# A deployed ClickHouse cluster must ship its S3 backup manifests.
# ──────────────────────────────────────────────────────────────────────────────
warn contains msg if {
	installation_present
	count(backup_manifests) == 0
	msg := "ClickHouse cluster is being deployed without any backup manifests. The S3 backup CronJobs must be present so telemetry data can be recovered."
}
