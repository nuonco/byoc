# IAM Privilege Escalation Policy (terraform_module)
#
# Certain GCP project-level roles on workload service accounts create direct
# privilege-escalation paths. A compromised pod with projectIamAdmin can bind
# roles/owner to itself; with serviceAccountTokenCreator it can mint tokens as
# any other SA. These must never appear on runtime workload identities.
#
# Checks:
#   - projectIamAdmin on a workload SA                         (deny)
#   - serviceAccountAdmin + serviceAccountUser combo           (warn)
#   - serviceAccountTokenCreator on a workload SA              (warn)
#
# Input: Terraform JSON plan (input.plan.resource_changes).

package nuon

import future.keywords.contains
import future.keywords.if
import future.keywords.in

project_iam_resources := {"google_project_iam_member", "google_project_iam_binding"}

# ──────────────────────────────────────────────────────────────────────────────
# roles/resourcemanager.projectIamAdmin is the single most dangerous role to
# grant a workload SA. It can modify ANY IAM binding in the project — including
# binding roles/owner to the SA itself. This is a one-hop escalation to full
# project ownership from any compromised pod.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	some rc in input.plan.resource_changes
	rc.type in project_iam_resources
	rc.change.actions[_] in ["create", "update"]
	rc.change.after.role == "roles/resourcemanager.projectIamAdmin"
	msg := sprintf(
		"IAM binding '%s' grants roles/resourcemanager.projectIamAdmin. This allows the SA to modify any IAM binding (including granting itself roles/owner). Use resource-level IAM bindings instead.",
		[rc.address],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# roles/iam.serviceAccountAdmin lets the SA create new service accounts and
# manage their keys. Combined with serviceAccountUser (ability to impersonate),
# this allows creating arbitrary identities.
#
# Warned because it's currently required for org runner provisioning.
# TODO: scope to a name prefix or replace with a custom role.
# ──────────────────────────────────────────────────────────────────────────────
warn contains msg if {
	some rc in input.plan.resource_changes
	rc.type in project_iam_resources
	rc.change.actions[_] in ["create", "update"]
	rc.change.after.role == "roles/iam.serviceAccountAdmin"
	msg := sprintf(
		"IAM binding '%s' grants roles/iam.serviceAccountAdmin at the project level. The SA can create/manage any service account. Scope to a name prefix or use a custom role.",
		[rc.address],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# roles/iam.serviceAccountTokenCreator lets the SA mint OAuth/OIDC tokens as
# ANY service account in the project. Combined with a privileged SA, this is
# an impersonation escalation path.
#
# Warned because it's currently required for GCS signed URL generation.
# TODO: move to SA-scoped token creator (on the specific SA, not project-level).
# ──────────────────────────────────────────────────────────────────────────────
warn contains msg if {
	some rc in input.plan.resource_changes
	rc.type in project_iam_resources
	rc.change.actions[_] in ["create", "update"]
	rc.change.after.role == "roles/iam.serviceAccountTokenCreator"
	msg := sprintf(
		"IAM binding '%s' grants roles/iam.serviceAccountTokenCreator at the project level. The SA can mint tokens as any SA. Scope to the specific SA that needs signing.",
		[rc.address],
	)
}
