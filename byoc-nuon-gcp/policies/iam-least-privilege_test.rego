package nuon

import future.keywords.if

# ── Helpers ───────────────────────────────────────────────────────────────────

mock_iam_member(role, member) := {"plan": {"resource_changes": [{
	"type": "google_project_iam_member",
	"address": "google_project_iam_member.test",
	"change": {
		"actions": ["create"],
		"after": {
			"role": role,
			"member": member,
			"project": "my-project",
		},
	},
}]}}

# ── Warn: broad project-level roles ──────────────────────────────────────────

test_warn_storage_admin if {
	count(warn) > 0 with input as mock_iam_member("roles/storage.admin", "serviceAccount:sa@proj.iam.gserviceaccount.com")
}

test_warn_container_admin if {
	count(warn) > 0 with input as mock_iam_member("roles/container.admin", "serviceAccount:sa@proj.iam.gserviceaccount.com")
}

test_warn_dns_admin if {
	count(warn) > 0 with input as mock_iam_member("roles/dns.admin", "serviceAccount:sa@proj.iam.gserviceaccount.com")
}

# ── Deny: roles/owner ───────────────────────────────────────────────────────

test_deny_owner if {
	count(deny) > 0 with input as mock_iam_member("roles/owner", "serviceAccount:sa@proj.iam.gserviceaccount.com")
}

# ── Deny: allUsers at project level ──────────────────────────────────────────

test_deny_all_users if {
	count(deny) > 0 with input as mock_iam_member("roles/viewer", "allUsers")
}

test_deny_all_authenticated_users if {
	count(deny) > 0 with input as mock_iam_member("roles/viewer", "allAuthenticatedUsers")
}

# ── Allow: narrow roles ──────────────────────────────────────────────────────

test_allow_log_writer if {
	inp := mock_iam_member("roles/logging.logWriter", "serviceAccount:sa@proj.iam.gserviceaccount.com")
	count(deny) == 0 with input as inp
	count(warn) == 0 with input as inp
}
