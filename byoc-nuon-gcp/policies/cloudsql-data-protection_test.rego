package nuon

import future.keywords.if

# ── Helpers ───────────────────────────────────────────────────────────────────

mock_cloudsql(deletion_protection, backup_enabled, pitr_enabled) := {"plan": {"resource_changes": [{
	"type": "google_sql_database_instance",
	"address": "google_sql_database_instance.nuon",
	"change": {
		"actions": ["create"],
		"after": {
			"deletion_protection": deletion_protection,
			"settings": [{
				"backup_configuration": [{
					"enabled": backup_enabled,
					"point_in_time_recovery_enabled": pitr_enabled,
				}],
			}],
		},
	},
}]}}

# ── Deny: deletion_protection = false ────────────────────────────────────────

test_deny_no_deletion_protection if {
	count(deny) > 0 with input as mock_cloudsql(false, true, true)
}

# ── Deny: backups disabled ───────────────────────────────────────────────────

test_deny_no_backups if {
	count(deny) > 0 with input as mock_cloudsql(true, false, true)
}

# ── Warn: PITR disabled ─────────────────────────────────────────────────────

test_warn_no_pitr if {
	count(warn) > 0 with input as mock_cloudsql(true, true, false)
}

# ── Pass: fully protected ───────────────────────────────────────────────────

test_pass_fully_protected if {
	inp := mock_cloudsql(true, true, true)
	count(deny) == 0 with input as inp
	count(warn) == 0 with input as inp
}
