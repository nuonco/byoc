package nuon

import future.keywords.if

# Uses mock_iam_member from iam-least-privilege_test.rego (same package, same directory).

# ── Deny: projectIamAdmin ────────────────────────────────────────────────────

test_deny_project_iam_admin if {
	count(deny) > 0 with input as mock_iam_member("roles/resourcemanager.projectIamAdmin", "serviceAccount:test@project.iam.gserviceaccount.com")
}

# ── Warn: serviceAccountAdmin ────────────────────────────────────────────────

test_warn_sa_admin if {
	count(warn) > 0 with input as mock_iam_member("roles/iam.serviceAccountAdmin", "serviceAccount:test@project.iam.gserviceaccount.com")
}

# ── Warn: serviceAccountTokenCreator ─────────────────────────────────────────

test_warn_token_creator if {
	count(warn) > 0 with input as mock_iam_member("roles/iam.serviceAccountTokenCreator", "serviceAccount:test@project.iam.gserviceaccount.com")
}

# ── Allow: safe roles ────────────────────────────────────────────────────────

test_allow_cloudsql_client if {
	inp := mock_iam_member("roles/cloudsql.client", "serviceAccount:test@project.iam.gserviceaccount.com")
	count(deny) == 0 with input as inp
	count(warn) == 0 with input as inp
}

test_allow_logging_writer if {
	inp := mock_iam_member("roles/logging.logWriter", "serviceAccount:test@project.iam.gserviceaccount.com")
	count(deny) == 0 with input as inp
	count(warn) == 0 with input as inp
}
