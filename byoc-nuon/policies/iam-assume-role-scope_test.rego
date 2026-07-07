package nuon

import future.keywords.if

# ── Helpers ───────────────────────────────────────────────────────────────────

mock_plan(policy_json) := {"plan": {"resource_changes": [{
	"type": "aws_iam_policy",
	"address": "aws_iam_policy.test",
	"change": {
		"actions": ["create"],
		"after": {"policy": policy_json},
	},
}]}}

policy_doc(actions, resources) := json.marshal({
	"Version": "2012-10-17",
	"Statement": [{"Effect": "Allow", "Action": actions, "Resource": resources}],
})

# ── Deny: sts:AssumeRole on * ────────────────────────────────────────────────

test_deny_assume_role_wildcard if {
	inp := mock_plan(policy_doc(["sts:AssumeRole"], ["*"]))
	count(deny) > 0 with input as inp
}

test_deny_sts_star_wildcard if {
	inp := mock_plan(policy_doc(["sts:*"], ["*"]))
	count(deny) > 0 with input as inp
}

# ── Allow: sts:AssumeRole scoped to specific ARN ─────────────────────────────

test_allow_assume_role_scoped if {
	inp := mock_plan(policy_doc(
		["sts:AssumeRole"],
		["arn:aws:iam::123456789012:role/specific-role"],
	))
	count(deny) == 0 with input as inp
}

# ── Allow: non-STS actions on * are not flagged by THIS policy ────────────────

test_allow_s3_wildcard_not_flagged if {
	inp := mock_plan(policy_doc(["s3:GetObject"], ["*"]))
	count(deny) == 0 with input as inp
}

# ── Allow: sts:AssumeRoleWithWebIdentity on * (OIDC federation, always scoped by condition) ──

test_allow_assume_role_web_identity if {
	inp := mock_plan(policy_doc(["sts:AssumeRoleWithWebIdentity"], ["*"]))
	count(deny) == 0 with input as inp
}
