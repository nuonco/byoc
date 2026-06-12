# No Cluster-Wide RBAC Policy (helm_chart, components: ctl_api, dashboard_ui)
#
# The control-plane API and dashboard should only ever hold namespaced RBAC
# (Role / RoleBinding). Cluster-scoped RBAC (ClusterRole / ClusterRoleBinding)
# grants permissions across the whole cluster and widens the blast radius if the
# workload is compromised.
#
# Checks:
#   - deny ClusterRole and ClusterRoleBinding objects   (deny)
#
# Input: Kubernetes AdmissionReview (input.review.object). ClusterRoles are
# cluster-scoped, so this is scoped by component rather than by namespace.

package nuon

import future.keywords.contains
import future.keywords.if
import future.keywords.in

deny contains msg if {
	input.review.kind.kind in {"ClusterRole", "ClusterRoleBinding"}
	msg := sprintf("%s '%s' is not allowed: this component must use namespaced RBAC (Role/RoleBinding), not cluster-wide RBAC.", [input.review.kind.kind, input.review.object.metadata.name])
}
