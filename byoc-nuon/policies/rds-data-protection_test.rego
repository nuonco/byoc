package nuon

import future.keywords.if

# ── Helpers ───────────────────────────────────────────────────────────────────

mock_rds(fields) := {"plan": {"resource_changes": [{
	"type": "aws_db_instance",
	"address": "module.db.aws_db_instance.this",
	"change": {
		"actions": ["create"],
		"after": fields,
	},
}]}}

mock_param_group(params) := {"plan": {"resource_changes": [{
	"type": "aws_db_parameter_group",
	"address": "module.db.aws_db_parameter_group.this",
	"change": {
		"actions": ["create"],
		"after": {"parameter": params},
	},
}]}}

# ── Deny: skip_final_snapshot = true ─────────────────────────────────────────

test_deny_skip_final_snapshot if {
	inp := mock_rds({
		"skip_final_snapshot": true,
		"deletion_protection": true,
		"storage_encrypted": true,
		"backup_retention_period": 7,
	})
	count(deny) > 0 with input as inp
}

# ── Deny: storage_encrypted = false ──────────────────────────────────────────

test_deny_unencrypted_storage if {
	inp := mock_rds({
		"skip_final_snapshot": false,
		"deletion_protection": true,
		"storage_encrypted": false,
		"backup_retention_period": 7,
	})
	count(deny) > 0 with input as inp
}

# ── Warn: force_ssl = 0 ─────────────────────────────────────────────────────

test_warn_ssl_disabled if {
	inp := mock_param_group([{"name": "rds.force_ssl", "value": "0"}])
	count(warn) > 0 with input as inp
}

# ── No warn: force_ssl = 1 ──────────────────────────────────────────────────

test_no_warn_ssl_enabled if {
	inp := mock_param_group([{"name": "rds.force_ssl", "value": "1"}])
	count(warn) == 0 with input as inp
}

# ── Warn: deletion_protection = false ────────────────────────────────────────

test_warn_no_deletion_protection if {
	inp := mock_rds({
		"skip_final_snapshot": false,
		"deletion_protection": false,
		"storage_encrypted": true,
		"backup_retention_period": 7,
	})
	count(warn) > 0 with input as inp
}

# ── Warn: low backup retention ───────────────────────────────────────────────

test_warn_low_backup_retention if {
	inp := mock_rds({
		"skip_final_snapshot": false,
		"deletion_protection": true,
		"storage_encrypted": true,
		"backup_retention_period": 3,
	})
	count(warn) > 0 with input as inp
}

# ── Pass: all protections enabled ────────────────────────────────────────────

test_pass_fully_protected if {
	inp := mock_rds({
		"skip_final_snapshot": false,
		"deletion_protection": true,
		"storage_encrypted": true,
		"backup_retention_period": 14,
	})
	count(deny) == 0 with input as inp
	count(warn) == 0 with input as inp
}
