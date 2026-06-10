# No LoadBalancer Services Policy (helm_chart)
#
# Control-plane traffic is meant to enter through the managed Ingress / ALB. A
# raw type: LoadBalancer Service silently provisions a public cloud load
# balancer, which can expose an internal service to the internet.
#
# Checks:
#   - deny Service type LoadBalancer   (deny)
#   - warn Service type NodePort        (warn)
#
# Input: Kubernetes AdmissionReview (input.review.object).
#
# If a workload genuinely needs a public load balancer, allowlist it here or
# relax this rule to `warn`.

package nuon

import future.keywords.contains
import future.keywords.if
import future.keywords.in

deny contains msg if {
	input.review.kind.kind == "Service"
	input.review.object.spec.type == "LoadBalancer"
	msg := sprintf(
		"Service '%s' is type LoadBalancer, which provisions a public cloud load balancer. Expose it through the managed Ingress instead.",
		[input.review.object.metadata.name],
	)
}

warn contains msg if {
	input.review.kind.kind == "Service"
	input.review.object.spec.type == "NodePort"
	msg := sprintf(
		"Service '%s' is type NodePort. Prefer an Ingress for control-plane endpoints.",
		[input.review.object.metadata.name],
	)
}
