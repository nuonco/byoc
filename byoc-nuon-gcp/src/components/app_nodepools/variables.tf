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
  description = "Machine type for the ctl-api node pool. ~AWS c5.large."
  default     = "e2-standard-2"
}
