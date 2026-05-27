# warns when a Helm chart deploys an Ingress that is publicly exposed.
#
# the sandbox provisions both ingress-nginx (ingressClassName "nginx") and
# the AWS Load Balancer Controller. that gives two ways to make an Ingress
# public:
#   1. AWS LBC: `alb.ingress.kubernetes.io/scheme: internet-facing` annotation
#      provisions a public ALB.
#   2. ingress-nginx: `cert-manager.io/cluster-issuer: public-issuer`
#      annotation routes through the public hosted zone.

package nuon

warn contains msg if {
	input.review.kind.kind == "Ingress"
	input.review.object.metadata.annotations["alb.ingress.kubernetes.io/scheme"] == "internet-facing"
	msg := sprintf("Ingress '%s' provisions a public ALB (alb.ingress.kubernetes.io/scheme=internet-facing); confirm this is intentional", [input.review.object.metadata.name])
}

warn contains msg if {
	input.review.kind.kind == "Ingress"
	input.review.object.metadata.annotations["cert-manager.io/cluster-issuer"] == "public-issuer"
	msg := sprintf("Ingress '%s' is public (cert-manager.io/cluster-issuer=public-issuer); confirm this is intentional", [input.review.object.metadata.name])
}
