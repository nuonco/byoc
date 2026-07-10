variable "install_id" {
  type = string
}

variable "project_id" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_location" {
  type = string
}

variable "gke_node_pool_sa_email" {
  type        = string
  description = "Least-privilege node SA from the install stack, shared with the sandbox main pool."
}

variable "temporal_machine_type" {
  type        = string
  description = "Machine type for the temporal node pool. ~AWS c5.xlarge."
  default     = "e2-standard-4"
}

variable "ctl_api_machine_type" {
  type        = string
  description = "Machine type for the ctl-api api/dashboard pool. ~AWS c5.large."
  default     = "e2-standard-2"
}

variable "ctl_api_worker_machine_type" {
  type        = string
  description = "Machine type for the ctl-api worker pool. ~AWS c5.xlarge; 2GB/vCPU matches the worker pods' request ratio."
  default     = "e2-custom-4-8192"
}

variable "temporal_max_nodes" {
  type    = number
  default = 10
}

variable "ctl_api_max_nodes" {
  type    = number
  default = 8
}

variable "ctl_api_worker_max_nodes" {
  type    = number
  default = 40
}

variable "ch_installation_machine_type" {
  type        = string
  description = "Machine type for the clickhouse-installation (server) node pool. ~AWS t3a.large/c5.large."
  default     = "e2-standard-2"
}

variable "ch_keeper_machine_type" {
  type = string
  # The keeper pod requests cpu:1, which does not fit shared-core e2-medium
  # (~940m allocatable); e2-standard-2 gives 2 dedicated vCPU.
  description = "Machine type for the clickhouse-keeper node pool. ~AWS t3a.medium/c5.medium (2 vCPU)."
  default     = "e2-standard-2"
}

variable "ch_installation_disk_size_gb" {
  type    = number
  default = 100
}

variable "ch_keeper_disk_size_gb" {
  type    = number
  default = 50
}

variable "ch_installation_max_nodes" {
  type    = number
  default = 4
}

variable "ch_keeper_node_count" {
  type        = number
  description = "Per-zone node count for the static clickhouse-keeper pool."
  default     = 1
}
