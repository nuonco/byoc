# ctl-api Control-Plane Integrity Policy (helm_chart, component: ctl_api)
#
# ctl-api is the Nuon control plane. These checks pin the security and integrity
# invariants of its rendered manifests so a values change cannot silently weaken
# the control plane running in the customer's project.
#
# Checks (all deny):
#   - database connection stays hardened: IAM auth + TLS
#   - the control plane is never opened to all users
#   - the admin API stays on the internal domain
#   - the ctl-api ServiceAccount keeps its Workload Identity annotation
#
# Input: Kubernetes AdmissionReview (input.review.object). ctl-api renders its
# `env` map into a ConfigMap named "ctl-api" that every Deployment consumes via
# envFrom, so that ConfigMap is the source of truth for these env values.

package nuon

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# DB_SSL_MODE values that keep the connection encrypted. CloudSQL is reached
# over the private VPC network with IAM auth; "require" is the floor, and the
# verify-* modes are stricter.
encrypted_ssl_modes := {"require", "verify-ca", "verify-full"}

# The ctl-api env ConfigMap (only defined when reviewing that object).
ctl_api_config := input.review.object.data if {
	input.review.kind.kind == "ConfigMap"
	input.review.object.metadata.name == "ctl-api"
}

# ──────────────────────────────────────────────────────────────────────────────
# Database connection must use IAM auth and TLS.
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
	not cfg.DB_SSL_MODE in encrypted_ssl_modes
	msg := sprintf("ctl-api must connect to its database over TLS (DB_SSL_MODE must be one of %v).", [encrypted_ssl_modes])
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
# The ctl-api ServiceAccount must carry its Workload Identity annotation, or
# ctl-api cannot impersonate its GCP service account (CloudSQL IAM auth, GCS,
# GAR, ... all fail).
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	input.review.kind.kind == "ServiceAccount"
	input.review.object.metadata.name == "ctl-api"
	not has_workload_identity
	msg := "ctl-api ServiceAccount is missing its iam.gke.io/gcp-service-account annotation; it will not be able to authenticate to GCP."
}

has_workload_identity if {
	sa := input.review.object.metadata.annotations["iam.gke.io/gcp-service-account"]
	sa != ""
}
