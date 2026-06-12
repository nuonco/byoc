# GCS Data Protection Policy (terraform_module)
#
# The GCS buckets in this app hold install templates and ClickHouse backups.
# They must never be publicly reachable and must retain object versions for
# recovery.
#
# Checks:
#   - bucket versioning must stay enabled               (deny)
#   - uniform bucket-level access must stay enabled      (deny)
#   - force_destroy must stay false                      (deny)
#   - public IAM grants (allUsers/...) are not allowed   (deny)
#
# Input: Terraform JSON plan (input.plan.resource_changes).

package nuon

import future.keywords.contains
import future.keywords.if
import future.keywords.in

public_members := {"allUsers", "allAuthenticatedUsers"}

# Buckets that are intentionally public: the install-templates bucket serves
# install templates that the customer's GCP project fetches over public HTTPS,
# so its allUsers objectViewer grant is deliberate.
intentionally_public_buckets := {"install_templates"}

# Buckets that hold immutable backup objects and do not require versioning.
unversioned_ok_buckets := {"clickhouse"}

bucket_exempt(address, names) if {
	some name in names
	contains(address, name)
}

is_bucket_change(rc) if {
	rc.type == "google_storage_bucket"
	rc.change.actions[_] in ["create", "update"]
}

# ──────────────────────────────────────────────────────────────────────────────
# Bucket versioning must remain enabled (protects against overwrite/delete).
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	some rc in input.plan.resource_changes
	is_bucket_change(rc)
	not bucket_exempt(rc.address, unversioned_ok_buckets)
	some cfg in rc.change.after.versioning
	cfg.enabled != true
	msg := sprintf(
		"GCS bucket '%s' disables versioning. Versioning must stay enabled so objects can be recovered.",
		[rc.address],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# Uniform bucket-level access disables object ACLs, so access is governed by
# IAM alone. Turning it off reopens the per-object public-ACL surface.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	some rc in input.plan.resource_changes
	is_bucket_change(rc)
	rc.change.after.uniform_bucket_level_access == false
	msg := sprintf(
		"GCS bucket '%s' has uniform_bucket_level_access=false. It must stay true so object ACLs cannot make data public.",
		[rc.address],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# Never set force_destroy - it lets a `terraform destroy` wipe every object in
# the bucket without any recovery path.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	some rc in input.plan.resource_changes
	is_bucket_change(rc)
	rc.change.after.force_destroy == true
	msg := sprintf(
		"GCS bucket '%s' has force_destroy=true, allowing a destroy to delete all objects. It must stay false so bucket data survives accidental deletion.",
		[rc.address],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# Never grant bucket access to allUsers / allAuthenticatedUsers, unless the
# bucket is intentionally public.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	some rc in input.plan.resource_changes
	rc.type in ["google_storage_bucket_iam_member", "google_storage_bucket_iam_binding"]
	rc.change.actions[_] in ["create", "update"]
	not bucket_exempt(rc.address, intentionally_public_buckets)
	some member in iam_members(rc.change.after)
	member in public_members
	msg := sprintf(
		"GCS IAM grant '%s' gives %q access via %q. Buckets must remain private.",
		[rc.address, member, rc.change.after.role],
	)
}

iam_members(after) := {after.member} if {
	is_string(after.member)
}

iam_members(after) := {m | some m in after.members} if {
	is_array(after.members)
}
