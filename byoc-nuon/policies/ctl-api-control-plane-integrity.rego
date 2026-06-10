# ctl-api Control-Plane Integrity Policy (helm_chart, component: ctl_api)
#
# ctl-api is the Nuon control plane. These checks pin the security and integrity
# invariants of its rendered manifests so a values change cannot silently weaken
# the control plane running in the customer's account.
#
# Checks (all deny):
#   - database connection stays hardened: IAM auth + TLS verify-full
#   - the control plane is never opened to all users
#   - the admin API stays on the internal domain
#   - the Nuon support role ARN is not swapped to another account
#   - the ctl-api ServiceAccount keeps its IRSA role annotation
#
# Input: Kubernetes AdmissionReview (input.review.object). ctl-api renders its
# `env` map into a ConfigMap named "ctl-api" that every Deployment consumes via
# envFrom, so that ConfigMap is the source of truth for these env values.

package nuon

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Nuon's support role lives in a fixed, Nuon-owned account. The BYOC trust model
# depends on this ARN: pointing it elsewhere would hand control-plane support
# access to another account.
nuon_support_role_arn := "arn:aws:iam::814326426574:role/nuon-internal-support-prod"

support_role_keys := {"ORG_RUNNER_SUPPORT_ROLE_ARN", "RUNNER_DEFAULT_SUPPORT_IAM_ROLE_ARN"}

# The ctl-api env ConfigMap (only defined when reviewing that object).
ctl_api_config := input.review.object.data if {
	input.review.kind.kind == "ConfigMap"
	input.review.object.metadata.name == "ctl-api"
}

# ──────────────────────────────────────────────────────────────────────────────
# Database connection must use IAM auth and TLS with full verification.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	cfg := ctl_api_config
	not cfg.DB_USE_IAM == "true"
	msg := "ctl-api must connect to its database with IAM auth (DB_USE_IAM=\"true\")."
}

deny contains msg if {
	cfg := ctl_api_config
	not cfg.DB_USE_SSL == "true"
	msg := "ctl-api must connect to its database over TLS (DB_USE_SSL=\"true\")."
}

deny contains msg if {
	cfg := ctl_api_config
	not cfg.DB_SSL_MODE == "verify-full"
	msg := "ctl-api must verify the database server certificate (DB_SSL_MODE=\"verify-full\")."
}

# ──────────────────────────────────────────────────────────────────────────────
# The control plane must never be opened to all users.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	cfg := ctl_api_config
	cfg.NUON_AUTH_ALLOW_ALL_USERS == "true"
	msg := "ctl-api has NUON_AUTH_ALLOW_ALL_USERS=\"true\", which opens the control plane to anyone. This is not allowed."
}

# ──────────────────────────────────────────────────────────────────────────────
# The admin API must stay on the internal domain, never the public one.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	cfg := ctl_api_config
	url := cfg.ADMIN_API_URL
	not contains(url, "internal.")
	msg := sprintf("ctl-api ADMIN_API_URL (%q) must resolve to the internal domain, not a public one.", [url])
}

# ──────────────────────────────────────────────────────────────────────────────
# The Nuon support role ARN must not be swapped to another account.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	cfg := ctl_api_config
	some key in support_role_keys
	arn := cfg[key]
	arn != nuon_support_role_arn
	msg := sprintf("ctl-api %s (%q) must be the Nuon support role %q.", [key, arn, nuon_support_role_arn])
}

# ──────────────────────────────────────────────────────────────────────────────
# The ctl-api ServiceAccount must carry its IRSA role annotation, or ctl-api
# cannot assume its AWS role (RDS IAM auth, S3, ECR, ... all fail).
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	input.review.kind.kind == "ServiceAccount"
	input.review.object.metadata.name == "ctl-api"
	not has_irsa_role
	msg := "ctl-api ServiceAccount is missing its eks.amazonaws.com/role-arn annotation; it will not be able to authenticate to AWS."
}

has_irsa_role if {
	arn := input.review.object.metadata.annotations["eks.amazonaws.com/role-arn"]
	arn != ""
}
