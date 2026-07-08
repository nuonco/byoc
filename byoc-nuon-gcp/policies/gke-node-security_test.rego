package nuon

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# ── Helpers ───────────────────────────────────────────────────────────────────

mock_node_pool(secure_boot, oauth_scopes) := {"plan": {"resource_changes": [{
	"type": "google_container_node_pool",
	"address": "google_container_node_pool.main",
	"change": {
		"actions": ["create"],
		"after": {"node_config": [{"shielded_instance_config": [{"enable_secure_boot": secure_boot}], "oauth_scopes": oauth_scopes}]},
	},
}]}}

mock_cluster(eval_mode) := {"plan": {"resource_changes": [{
	"type": "google_container_cluster",
	"address": "google_container_cluster.main",
	"change": {
		"actions": ["create"],
		"after": {"binary_authorization": [{"evaluation_mode": eval_mode}]},
	},
}]}}

# Helper: check if any warn message matches a substring.
has_warn_containing(substr) if {
	some msg in warn
	contains(msg, substr)
}

has_deny_containing(substr) if {
	some msg in deny
	contains(msg, substr)
}

# ── Deny: Secure Boot disabled ────────────────────────────────────────────────

test_deny_secure_boot_disabled if {
	has_deny_containing("Secure Boot") with input as mock_node_pool(false, [])
}

test_no_deny_secure_boot_enabled if {
	not has_deny_containing("Secure Boot") with input as mock_node_pool(true, [])
}

# ── Warn: Binary Authorization disabled ──────────────────────────────────────

test_warn_binary_auth_disabled if {
	has_warn_containing("Binary Authorization") with input as mock_cluster("DISABLED")
}

test_no_warn_binary_auth_enabled if {
	not has_warn_containing("Binary Authorization") with input as mock_cluster("PROJECT_SINGLETON_POLICY_ENFORCE")
}

# ── Warn: cloud-platform OAuth scope ────────────────────────────────────────

test_warn_cloud_platform_scope if {
	has_warn_containing("cloud-platform OAuth scope") with input as mock_node_pool(true, ["https://www.googleapis.com/auth/cloud-platform"])
}

test_no_warn_restricted_scopes if {
	not has_warn_containing("cloud-platform OAuth scope") with input as mock_node_pool(true, [
		"https://www.googleapis.com/auth/logging.write",
		"https://www.googleapis.com/auth/monitoring",
	])
}
