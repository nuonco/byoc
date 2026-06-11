# EKS Endpoint Access Policy (sandbox)
#
# The sandbox provisions the EKS cluster that hosts the entire control plane.
# A public Kubernetes API endpoint open to 0.0.0.0/0 is a large attack surface
# for a control plane running in a customer account.
#
# Checks:
#   - EKS API endpoint should not be public / unrestricted   (warn -> deny)
#
# Input: Terraform JSON plan from the sandbox run
#        (input.plan.resource_changes).

package nuon

import future.keywords.contains
import future.keywords.if
import future.keywords.in

vpc_configs(rc) := configs if {
	is_array(rc.change.after.vpc_config)
	configs := rc.change.after.vpc_config
}

vpc_configs(rc) := [rc.change.after.vpc_config] if {
	is_object(rc.change.after.vpc_config)
}

# ──────────────────────────────────────────────────────────────────────────────
# Warn when the EKS public endpoint is open to the entire internet.
#
# Warns so a sandbox that still uses a public endpoint is not blocked. TODO:
# promote to `deny` once the cluster API is restricted to known CIDRs (or the
# public endpoint is disabled).
# ──────────────────────────────────────────────────────────────────────────────
warn contains msg if {
	some rc in input.plan.resource_changes
	rc.type == "aws_eks_cluster"
	rc.change.actions[_] in ["create", "update"]
	some cfg in vpc_configs(rc)
	cfg.endpoint_public_access == true
	some cidr in cfg.public_access_cidrs
	cidr == "0.0.0.0/0"
	msg := sprintf(
		"EKS cluster '%s' exposes its public API endpoint to 0.0.0.0/0. Restrict public_access_cidrs or disable the public endpoint.",
		[rc.address],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# Also warn when the public endpoint is enabled with no CIDR restriction at all
# (an empty/absent allowlist defaults to 0.0.0.0/0).
# ──────────────────────────────────────────────────────────────────────────────
warn contains msg if {
	some rc in input.plan.resource_changes
	rc.type == "aws_eks_cluster"
	rc.change.actions[_] in ["create", "update"]
	some cfg in vpc_configs(rc)
	cfg.endpoint_public_access == true
	count(object.get(cfg, "public_access_cidrs", [])) == 0
	msg := sprintf(
		"EKS cluster '%s' enables the public API endpoint without a public_access_cidrs allowlist (defaults to 0.0.0.0/0). Restrict it to known CIDRs.",
		[rc.address],
	)
}
