# No Cluster-Wide RBAC Policy (helm_chart, components: ctl_api, dashboard_ui)
#
# The control-plane API and dashboard should only ever hold namespaced RBAC
# (Role / RoleBinding). Cluster-scoped RBAC (ClusterRole / ClusterRoleBinding)
# grants permissions across the whole cluster and widens the blast radius if the
# workload is compromised.
#
# Checks:
#   - warn on ClusterRole and ClusterRoleBinding objects   (warn)
#
# Input: Kubernetes AdmissionReview (input.review.object). ClusterRoles are
# cluster-scoped, so this is scoped by component rather than by namespace.

package nuon

import future.keywords.contains
import future.keywords.if
import future.keywords.in

warn contains msg if {
	input.review.kind.kind in {"ClusterRole", "ClusterRoleBinding"}
	not is_deletion
	msg := sprintf("%s '%s' uses cluster-wide RBAC; prefer namespaced RBAC (Role/RoleBinding) to limit blast radius.", [input.review.kind.kind, input.review.object.metadata.name])
}

# Objects being removed (e.g. a helm uninstall / teardown) are exempt: tearing
# down existing cluster-wide RBAC reduces blast radius and must not be warned on.
# Only an explicit DELETE operation suppresses the rule; an unknown/absent
# operation fails safe and is still treated as a creation.
is_deletion if {
	input.review.operation == "DELETE"
}
