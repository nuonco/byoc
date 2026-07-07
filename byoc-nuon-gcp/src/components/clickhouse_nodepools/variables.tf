variable "install_id" {
  type = string
}

variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

# The GKE cluster the node pools attach to. For a regional cluster this is the
# region (e.g. us-central1); the node pools inherit the cluster's node_locations
# so they span every zone the cluster runs in.
variable "cluster_name" {
  type = string
}

variable "cluster_location" {
  type = string
}

variable "installation_machine_type" {
  type        = string
  description = "Machine type for the clickhouse-installation (server) node pool. ~AWS t3a.large/c5.large."
  default     = "e2-standard-2"
}

variable "keeper_machine_type" {
  type = string
  # AWS keeper runs on t3a.medium/c5.medium = 2 vCPU. The keeper pod requests
  # cpu:1 (1000m), which does NOT fit an e2-medium: it's a shared-core type with
  # only ~940m allocatable CPU after GKE system reservations, so the pod stays
  # Pending with "Insufficient cpu". e2-standard-2 gives 2 dedicated vCPU
  # (~1930m allocatable), matching the AWS 2-vCPU keeper node.
  description = "Machine type for the clickhouse-keeper node pool. ~AWS t3a.medium/c5.medium (2 vCPU)."
  default     = "e2-standard-2"
}

variable "installation_disk_size_gb" {
  type    = number
  default = 100
}

variable "keeper_disk_size_gb" {
  type    = number
  default = 50
}
