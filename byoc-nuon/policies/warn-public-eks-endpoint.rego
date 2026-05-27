# warns when the EKS cluster has its API server endpoint exposed publicly.
# the sandbox controls this via `cluster_endpoint_public_access` in
# sandbox.tfvars, so this policy is scoped to type = "sandbox".

package nuon

warn contains msg if {
	resource := input.plan.resource_changes[_]
	resource.type == "aws_eks_cluster"
	resource.mode == "managed"
	vpc := resource.change.after.vpc_config[_]
	vpc.endpoint_public_access == true
	msg := sprintf("EKS cluster '%s' has public endpoint access enabled", [resource.address])
}
