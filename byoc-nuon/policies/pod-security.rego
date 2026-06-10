# Pod Security Policy (helm_chart)
#
# Baseline workload hardening for everything the control plane runs on the
# cluster: no privileged escalation to the node, and workloads should not run as
# root.
#
# Checks:
#   - deny privileged containers / host namespace sharing   (deny)
#   - containers should run as non-root                       (warn -> deny)
#
# Input: Kubernetes AdmissionReview (input.review.object).

package nuon

import future.keywords.contains
import future.keywords.if
import future.keywords.in

pod_spec_resources := {"Pod", "Deployment", "StatefulSet", "DaemonSet", "Job", "CronJob", "ReplicaSet"}

get_pod_spec(obj) := obj.spec if {
	input.review.kind.kind == "Pod"
}

get_pod_spec(obj) := obj.spec.template.spec if {
	input.review.kind.kind in {"Deployment", "StatefulSet", "DaemonSet", "ReplicaSet", "Job"}
}

get_pod_spec(obj) := obj.spec.jobTemplate.spec.template.spec if {
	input.review.kind.kind == "CronJob"
}

all_containers(pod_spec) := array.concat(
	object.get(pod_spec, "containers", []),
	object.get(pod_spec, "initContainers", []),
)

# ──────────────────────────────────────────────────────────────────────────────
# Privileged containers can take over the node - never allow them.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	input.review.kind.kind in pod_spec_resources
	pod_spec := get_pod_spec(input.review.object)
	some container in all_containers(pod_spec)
	container.securityContext.privileged == true
	msg := sprintf(
		"%s '%s' container '%s' runs in privileged mode. Privileged containers are not allowed on the control-plane cluster.",
		[input.review.kind.kind, input.review.object.metadata.name, container.name],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# Host namespace sharing is an escape hatch onto the node.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	input.review.kind.kind in pod_spec_resources
	pod_spec := get_pod_spec(input.review.object)
	some field in ["hostNetwork", "hostPID", "hostIPC"]
	pod_spec[field] == true
	msg := sprintf(
		"%s '%s' sets %s=true. Sharing host namespaces is not allowed on the control-plane cluster.",
		[input.review.kind.kind, input.review.object.metadata.name, field],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# Workloads should run as non-root.
#
# Warns so workloads without an explicit non-root setting are not blocked.
# TODO: promote to `deny` once all charts set securityContext.runAsNonRoot=true
# at the pod or container level.
# ──────────────────────────────────────────────────────────────────────────────
warn contains msg if {
	input.review.kind.kind in pod_spec_resources
	pod_spec := get_pod_spec(input.review.object)
	some container in all_containers(pod_spec)
	not container.securityContext.runAsNonRoot
	not pod_spec.securityContext.runAsNonRoot
	msg := sprintf(
		"%s '%s' container '%s' may run as root. Set securityContext.runAsNonRoot=true at the pod or container level.",
		[input.review.kind.kind, input.review.object.metadata.name, container.name],
	)
}
