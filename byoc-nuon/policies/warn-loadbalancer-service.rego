# warns when a Helm chart deploys a Kubernetes Service of type LoadBalancer.
# such a Service triggers the cloud controller to provision a cloud load
# balancer (in our case a public NLB by default), bypassing the sandbox's
# managed ingress path. all north-south traffic should go through
# ingress-nginx or the AWS Load Balancer Controller via an Ingress.

package nuon

warn contains msg if {
	input.review.kind.kind == "Service"
	input.review.object.spec.type == "LoadBalancer"
	msg := sprintf("Service '%s' is type=LoadBalancer; route through an Ingress instead", [input.review.object.metadata.name])
}
