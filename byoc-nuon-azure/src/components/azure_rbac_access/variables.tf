variable "subscription_id" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "aks_cluster_id" {
  type = string
}

variable "maintenance_principal_object_id" {
  type    = string
  default = ""
}

variable "break_glass_principal_object_id" {
  type    = string
  default = ""
}
