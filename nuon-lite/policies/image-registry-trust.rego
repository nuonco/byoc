# Image Registry Trust Policy (container_image)
#
# The BYOC trust model depends on running only images Nuon publishes or vets.
# First-party images must come from the Nuon ECR account; third-party images are
# limited to the specific upstreams this app ships (ClickHouse and Temporal).
#
# Checks:
#   - image must come from a trusted registry / namespace   (warn -> deny)
#
# Input: container image metadata (input.image, input.tag, input.metadata).

package nuon

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Nuon publishes first-party images (ctl-api, dashboard-ui, ...) from this ECR
# account.
nuon_ecr_account := "431927561584"

# Trusted upstream namespaces for the third-party images this app deploys.
trusted_namespaces := {"altinity/", "clickhouse/", "temporalio/"}

is_trusted if {
	contains(input.image, sprintf("%s.dkr.ecr", [nuon_ecr_account]))
}

is_trusted if {
	some ns in trusted_namespaces
	startswith(input.image, ns)
}

is_trusted if {
	some ns in trusted_namespaces
	contains(input.image, sprintf("/%s", [ns]))
}

# ──────────────────────────────────────────────────────────────────────────────
# Image must come from a trusted source.
#
# Warns so a registry-format mismatch cannot block all builds. TODO: promote to
# `deny` once verified against real container_image evaluation input.
# ──────────────────────────────────────────────────────────────────────────────
warn contains msg if {
	is_string(input.image)
	input.image != ""
	not is_trusted
	msg := sprintf("Image %q is not from a trusted registry. First-party images must come from the Nuon ECR account %s; third-party images must come from %v.", [input.image, nuon_ecr_account, trusted_namespaces])
}
