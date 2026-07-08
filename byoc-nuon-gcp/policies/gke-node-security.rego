# GKE Node Security Policy (sandbox)
#
# GKE node pool and cluster settings that affect the security posture of every
# pod running on the cluster. These checks cover the infrastructure baseline
# that the Nuon control plane inherits from the sandbox.
#
# Checks:
#   - Secure Boot disabled on node pool                  (warn)
#   - Binary Authorization disabled on cluster           (warn)
#   - oauth_scopes includes cloud-platform (too broad)   (warn)
#
# Input: Terraform JSON plan from the sandbox run
#        (input.plan.resource_changes).

package nuon

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# ──────────────────────────────────────────────────────────────────────────────
# Secure Boot prevents rootkit/bootkit attacks at the firmware level. Disabling
# it is unrelated to NET_ADMIN or any container-level capability.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	some rc in input.plan.resource_changes
	rc.type == "google_container_node_pool"
	rc.change.actions[_] in ["create", "update"]
	some cfg in object.get(rc.change.after, "node_config", [])
	some shield in object.get(cfg, "shielded_instance_config", [])
	shield.enable_secure_boot == false
	msg := sprintf(
		"GKE node pool '%s' has Secure Boot disabled. Enable it to prevent persistent kernel-level compromise.",
		[rc.address],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# Binary Authorization enforces that only attested container images can run on
# the cluster. Disabling it means any image — including malicious ones — can be
# deployed.
# ──────────────────────────────────────────────────────────────────────────────
warn contains msg if {
	some rc in input.plan.resource_changes
	rc.type == "google_container_cluster"
	rc.change.actions[_] in ["create", "update"]
	some ba in object.get(rc.change.after, "binary_authorization", [])
	ba.evaluation_mode == "DISABLED"
	msg := sprintf(
		"GKE cluster '%s' has Binary Authorization disabled. Enable it to enforce image attestation.",
		[rc.address],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# The cloud-platform OAuth scope grants access to ALL GCP APIs. While Workload
# Identity should take precedence for annotated pods, any pod that does NOT use
# WI inherits the node's scope — full API access via the node SA.
# ──────────────────────────────────────────────────────────────────────────────
warn contains msg if {
	some rc in input.plan.resource_changes
	rc.type == "google_container_node_pool"
	rc.change.actions[_] in ["create", "update"]
	some cfg in object.get(rc.change.after, "node_config", [])
	some scope in object.get(cfg, "oauth_scopes", [])
	scope == "https://www.googleapis.com/auth/cloud-platform"
	msg := sprintf(
		"GKE node pool '%s' uses the cloud-platform OAuth scope (full GCP API access). Restrict to logging.write, monitoring, and devstorage.read_only.",
		[rc.address],
	)
}
