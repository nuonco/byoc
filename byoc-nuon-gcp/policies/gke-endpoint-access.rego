# GKE Endpoint Access Policy (sandbox)
#
# The sandbox provisions the GKE cluster that hosts the entire control plane.
# A public Kubernetes API endpoint open to 0.0.0.0/0 is a large attack surface
# for a control plane running in a customer project.
#
# Checks:
#   - GKE API endpoint should not be public / unrestricted   (deny)
#
# Input: Terraform JSON plan from the sandbox run
#        (input.plan.resource_changes).

package nuon

import future.keywords.contains
import future.keywords.if
import future.keywords.in

master_authorized_networks(rc) := configs if {
	is_array(rc.change.after.master_authorized_networks_config)
	configs := rc.change.after.master_authorized_networks_config
}

master_authorized_networks(rc) := [rc.change.after.master_authorized_networks_config] if {
	is_object(rc.change.after.master_authorized_networks_config)
}

private_endpoint_enabled(rc) if {
	some cfg in rc.change.after.private_cluster_config
	cfg.enable_private_endpoint == true
}

is_cluster_change(rc) if {
	rc.type == "google_container_cluster"
	rc.change.actions[_] in ["create", "update"]
}

# ──────────────────────────────────────────────────────────────────────────────
# Deny when the GKE public endpoint is open to the entire internet. The
# sandbox runs with a private endpoint restricted to the install-stack VPC.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	some rc in input.plan.resource_changes
	is_cluster_change(rc)
	some cfg in master_authorized_networks(rc)
	some block in cfg.cidr_blocks
	block.cidr_block == "0.0.0.0/0"
	msg := sprintf(
		"GKE cluster '%s' exposes its API endpoint to 0.0.0.0/0 via master_authorized_networks_config. Restrict the cidr_blocks or enable the private endpoint.",
		[rc.address],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# Also deny when the public endpoint is enabled with no authorized-networks
# restriction at all (an absent allowlist leaves the endpoint open to any IP).
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	some rc in input.plan.resource_changes
	is_cluster_change(rc)
	not private_endpoint_enabled(rc)
	count(object.get(rc.change.after, "master_authorized_networks_config", [])) == 0
	msg := sprintf(
		"GKE cluster '%s' enables the public API endpoint without a master_authorized_networks_config allowlist (open to any IP). Restrict it to known CIDRs.",
		[rc.address],
	)
}
