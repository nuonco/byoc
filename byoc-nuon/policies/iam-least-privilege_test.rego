package nuon

import future.keywords.if

# ── Helpers ───────────────────────────────────────────────────────────────────

mock_policy(policy_json) := {"plan": {"resource_changes": [{
	"type": "aws_iam_policy",
	"address": "aws_iam_policy.test",
	"change": {
		"actions": ["create"],
		"after": {"policy": policy_json},
	},
}]}}

mock_attachment(policy_arn) := {"plan": {"resource_changes": [{
	"type": "aws_iam_role_policy_attachment",
	"address": "aws_iam_role_policy_attachment.test",
	"change": {
		"actions": ["create"],
		"after": {"policy_arn": policy_arn},
	},
}]}}

policy_doc(actions, resources) := json.marshal({
	"Version": "2012-10-17",
	"Statement": [{"Effect": "Allow", "Action": actions, "Resource": resources}],
})

# ── Warn: service-wide wildcards ──────────────────────────────────────────────

test_warn_s3_star if {
	inp := mock_policy(policy_doc(["s3:*"], ["*"]))
	count(warn) > 0 with input as inp
}

test_warn_iam_star if {
	inp := mock_policy(policy_doc(["iam:*"], ["*"]))
	count(warn) > 0 with input as inp
}

test_warn_kms_star if {
	inp := mock_policy(policy_doc(["kms:*"], ["*"]))
	count(warn) > 0 with input as inp
}

test_warn_full_star if {
	inp := mock_policy(policy_doc(["*"], ["*"]))
	count(warn) > 0 with input as inp
}

# ── No warn: scoped actions ──────────────────────────────────────────────────

test_no_warn_scoped_actions if {
	inp := mock_policy(policy_doc(["s3:GetObject", "s3:PutObject"], ["arn:aws:s3:::my-bucket/*"]))
	count(warn) == 0 with input as inp
}

# ── Warn: write actions on Resource * ────────────────────────────────────────

test_warn_create_on_star if {
	inp := mock_policy(policy_doc(["s3:CreateBucket"], ["*"]))
	count(warn) > 0 with input as inp
}

test_warn_delete_on_star if {
	inp := mock_policy(policy_doc(["iam:DeleteRole"], ["*"]))
	count(warn) > 0 with input as inp
}

# ── Deny: AdministratorAccess attachment ─────────────────────────────────────

test_deny_admin_access_attachment if {
	inp := mock_attachment("arn:aws:iam::aws:policy/AdministratorAccess")
	count(deny) > 0 with input as inp
}

# ── Allow: non-admin attachment ──────────────────────────────────────────────

test_allow_normal_attachment if {
	inp := mock_attachment("arn:aws:iam::aws:policy/ReadOnlyAccess")
	count(deny) == 0 with input as inp
}
