package nuon

import future.keywords.if

mock_change(type, actions) := {"plan": {"resource_changes": [{
	"type": type,
	"address": sprintf("mock.%s.this", [type]),
	"change": {"actions": actions},
}]}}

# ── Deny: pure destroy ────────────────────────────────────────────────────────

test_deny_db_instance_delete if {
	count(deny) > 0 with input as mock_change("aws_db_instance", ["delete"])
}

test_deny_s3_bucket_delete if {
	count(deny) > 0 with input as mock_change("aws_s3_bucket", ["delete"])
}

test_deny_kms_key_delete if {
	count(deny) > 0 with input as mock_change("aws_kms_key", ["delete"])
}

test_deny_secret_delete if {
	count(deny) > 0 with input as mock_change("aws_secretsmanager_secret", ["delete"])
}

# ── Deny: replace (delete then create, or create then delete) ─────────────────

test_deny_db_instance_replace if {
	count(deny) > 0 with input as mock_change("aws_db_instance", ["delete", "create"])
}

test_deny_s3_bucket_replace if {
	count(deny) > 0 with input as mock_change("aws_s3_bucket", ["create", "delete"])
}

test_deny_kms_key_replace if {
	count(deny) > 0 with input as mock_change("aws_kms_key", ["delete", "create"])
}

test_deny_secret_replace if {
	count(deny) > 0 with input as mock_change("aws_secretsmanager_secret", ["create", "delete"])
}

# ── Allow: create, in-place update, no-op ─────────────────────────────────────

test_allow_create if {
	count(deny) == 0 with input as mock_change("aws_db_instance", ["create"])
}

test_allow_update if {
	count(deny) == 0 with input as mock_change("aws_db_instance", ["update"])
}

test_allow_no_op if {
	count(deny) == 0 with input as mock_change("aws_s3_bucket", ["no-op"])
}

# ── Allow: non-critical types ─────────────────────────────────────────────────

test_allow_secret_version_delete if {
	count(deny) == 0 with input as mock_change("aws_secretsmanager_secret_version", ["delete"])
}

test_allow_parameter_group_replace if {
	count(deny) == 0 with input as mock_change("aws_db_parameter_group", ["delete", "create"])
}
