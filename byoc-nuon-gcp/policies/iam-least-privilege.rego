# IAM Least-Privilege Policy (terraform_module)
#
# The control plane provisions IAM bindings for its service accounts and for the
# org/runner machinery. Over-broad grants here are a privilege-escalation risk in
# the customer's project. This nudges those grants toward least privilege.
#
# Checks:
#   - broad project-level roles (editor, service admin roles)   (warn -> deny)
#   - roles/owner bound by a deployed component                  (deny)
#   - project access granted to allUsers/allAuthenticatedUsers   (deny)
#
# Input: Terraform JSON plan (input.plan.resource_changes).

package nuon

import future.keywords.contains
import future.keywords.if
import future.keywords.in

project_iam_resources := {"google_project_iam_member", "google_project_iam_binding"}

public_members := {"allUsers", "allAuthenticatedUsers"}

# Project-wide roles that grant far more than any single workload needs: the
# primitive editor role and service-wide admin roles (the GCP analog of
# service-wide wildcard actions like "s3:*").
broad_roles := {
	"roles/editor",
	"roles/storage.admin",
	"roles/artifactregistry.admin",
	"roles/dns.admin",
	"roles/container.admin",
	"roles/compute.admin",
	"roles/iam.serviceAccountAdmin",
	"roles/iam.securityAdmin",
	"roles/resourcemanager.projectIamAdmin",
}

# Helpers ─────────────────────────────────────────────────────────────────────
iam_members(after) := {after.member} if {
	is_string(after.member)
}

iam_members(after) := {m | some m in after.members} if {
	is_array(after.members)
}

is_project_iam_change(rc) if {
	rc.type in project_iam_resources
	rc.change.actions[_] in ["create", "update"]
}

# ──────────────────────────────────────────────────────────────────────────────
# Flag broad project-level roles.
#
# Warns so existing broad grants are not blocked while they are scoped down.
# TODO: promote to `deny` once project-wide admin roles are replaced with
# resource-scoped bindings or custom roles.
# ──────────────────────────────────────────────────────────────────────────────
warn contains msg if {
	some rc in input.plan.resource_changes
	is_project_iam_change(rc)
	rc.change.after.role in broad_roles
	msg := sprintf(
		"IAM binding '%s' grants broad project-level role '%s'. Scope it to the specific resources the workload requires.",
		[rc.address, rc.change.after.role],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# roles/owner must only ever be granted via the dedicated break-glass
# machinery, never bound by a normally-applied Terraform component.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	some rc in input.plan.resource_changes
	is_project_iam_change(rc)
	rc.change.after.role == "roles/owner"
	msg := sprintf(
		"IAM binding '%s' grants roles/owner. Owner access must only come from the break-glass role, not a deployed component.",
		[rc.address],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# Never grant project access to all users.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	some rc in input.plan.resource_changes
	is_project_iam_change(rc)
	some member in iam_members(rc.change.after)
	member in public_members
	msg := sprintf(
		"IAM binding '%s' grants %q the project-level role '%s'. Project access must never be public.",
		[rc.address, member, rc.change.after.role],
	)
}
