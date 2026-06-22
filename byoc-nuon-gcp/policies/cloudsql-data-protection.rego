# CloudSQL Data Protection Policy (terraform_module)
#
# Guards the two control-plane Postgres instances (ctl-api + Temporal) against
# the most catastrophic production failure modes: losing or exposing the
# database that backs the entire Nuon install.
#
# Checks:
#   - deletion_protection must be enabled               (deny)
#   - automated backups must be enabled                  (deny)
#   - point-in-time recovery should be enabled           (warn)
#   - the instance must not get a public IPv4 address    (deny)
#   - unencrypted connections must not be allowed        (warn -> deny)
#
# Input: Terraform JSON plan (input.plan.resource_changes).

package nuon

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Terraform plan JSON renders nested blocks as arrays.
instance_settings(rc) := cfgs if {
	is_array(rc.change.after.settings)
	cfgs := rc.change.after.settings
}

instance_settings(rc) := [rc.change.after.settings] if {
	is_object(rc.change.after.settings)
}

is_sql_instance_change(rc) if {
	rc.type == "google_sql_database_instance"
	rc.change.actions[_] in ["create", "update"]
}

# ──────────────────────────────────────────────────────────────────────────────
# CloudSQL deletion protection.
#
# Every CloudSQL component now sets deletion_protection = true, so this is a
# hard deny: the control-plane database must never be deployable without it.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	some rc in input.plan.resource_changes
	is_sql_instance_change(rc)
	rc.change.after.deletion_protection == false
	msg := sprintf(
		"CloudSQL instance '%s' has deletion_protection disabled. The control-plane database must be protected from accidental deletion.",
		[rc.address],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# Automated backups are the last line of defense against data loss.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	some rc in input.plan.resource_changes
	is_sql_instance_change(rc)
	some settings in instance_settings(rc)
	some backup in settings.backup_configuration
	backup.enabled == false
	msg := sprintf(
		"CloudSQL instance '%s' has automated backups disabled. Backups must be enabled so the database can be recovered.",
		[rc.address],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# Point-in-time recovery window. Kept as a warning so the setting stays tunable.
# ──────────────────────────────────────────────────────────────────────────────
warn contains msg if {
	some rc in input.plan.resource_changes
	is_sql_instance_change(rc)
	some settings in instance_settings(rc)
	some backup in settings.backup_configuration
	backup.point_in_time_recovery_enabled == false
	msg := sprintf(
		"CloudSQL instance '%s' has point_in_time_recovery_enabled=false. Enable it to survive accidental data loss.",
		[rc.address],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# The control-plane database must stay on the private VPC network only.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	some rc in input.plan.resource_changes
	is_sql_instance_change(rc)
	some settings in instance_settings(rc)
	some ip_cfg in settings.ip_configuration
	ip_cfg.ipv4_enabled == true
	msg := sprintf(
		"CloudSQL instance '%s' enables a public IPv4 address. The control-plane database must only be reachable over the private VPC network.",
		[rc.address],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# Enforce TLS for database connections via ip_configuration.ssl_mode.
#
# Warns during the TLS rollout. TODO: promote to `deny` once every CloudSQL
# instance sets ssl_mode = "ENCRYPTED_ONLY" (or stricter).
# ──────────────────────────────────────────────────────────────────────────────
warn contains msg if {
	some rc in input.plan.resource_changes
	is_sql_instance_change(rc)
	some settings in instance_settings(rc)
	some ip_cfg in settings.ip_configuration
	ip_cfg.ssl_mode == "ALLOW_UNENCRYPTED_AND_ENCRYPTED"
	msg := sprintf(
		"CloudSQL instance '%s' sets ssl_mode=ALLOW_UNENCRYPTED_AND_ENCRYPTED, allowing unencrypted database connections. Set it to ENCRYPTED_ONLY (or stricter) to require TLS.",
		[rc.address],
	)
}
