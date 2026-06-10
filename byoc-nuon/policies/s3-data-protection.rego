# S3 Data Protection Policy (terraform_module)
#
# The S3 buckets in this app hold blob storage and ClickHouse backups. They must
# never be publicly reachable and must retain object versions for recovery.
#
# Checks:
#   - bucket versioning must stay Enabled        (deny)
#   - buckets must have a public-access block     (warn -> deny)
#   - public-access block flags must all be true  (deny)
#   - public bucket ACLs are not allowed          (deny)
#
# Input: Terraform JSON plan (input.plan.resource_changes).

package nuon

import future.keywords.contains
import future.keywords.if
import future.keywords.in

public_acls := {"public-read", "public-read-write", "authenticated-read"}

# ──────────────────────────────────────────────────────────────────────────────
# Bucket versioning must remain Enabled (protects against overwrite/delete).
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	some rc in input.plan.resource_changes
	rc.type == "aws_s3_bucket_versioning"
	rc.change.actions[_] in ["create", "update"]
	some cfg in rc.change.after.versioning_configuration
	cfg.status != "Enabled"
	msg := sprintf(
		"S3 versioning '%s' sets status=%q. Versioning must stay Enabled so objects can be recovered.",
		[rc.address, cfg.status],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# Every bucket should be covered by an aws_s3_bucket_public_access_block.
#
# Warns so buckets without a block are not yet blocked. TODO: promote to `deny`
# once every bucket ships a public-access block, so a missing one fails the plan.
# ──────────────────────────────────────────────────────────────────────────────
warn contains msg if {
	some rc in input.plan.resource_changes
	rc.type == "aws_s3_bucket"
	rc.change.actions[_] in ["create", "update"]
	count(public_access_blocks) == 0
	msg := sprintf(
		"S3 bucket '%s' is provisioned without any aws_s3_bucket_public_access_block in the plan. Add one (all four flags true) to guarantee the bucket cannot be made public.",
		[rc.address],
	)
}

public_access_blocks := [rc |
	some rc in input.plan.resource_changes
	rc.type == "aws_s3_bucket_public_access_block"
]

# ──────────────────────────────────────────────────────────────────────────────
# A public-access block that disables any protection defeats its purpose.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	some rc in input.plan.resource_changes
	rc.type == "aws_s3_bucket_public_access_block"
	rc.change.actions[_] in ["create", "update"]
	after := rc.change.after
	some field in ["block_public_acls", "block_public_policy", "ignore_public_acls", "restrict_public_buckets"]
	after[field] == false
	msg := sprintf(
		"S3 public-access block '%s' has %s=false. All four public-access protections must be true.",
		[rc.address, field],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# Never set a public bucket ACL.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	some rc in input.plan.resource_changes
	rc.type in ["aws_s3_bucket_acl", "aws_s3_bucket"]
	rc.change.actions[_] in ["create", "update"]
	rc.change.after.acl in public_acls
	msg := sprintf(
		"S3 resource '%s' sets a public ACL (%q). Buckets must remain private.",
		[rc.address, rc.change.after.acl],
	)
}
