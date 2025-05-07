variable "secrets" {
  type = list(object({
    arn       = string,
    namespace = string,
    name      = string,
  }))
  description = "List of secret arns and their target name and namespace. These will be copied from AWS Secret Manager into K8S."
}

variable "region" {
  type = string
}

variable "cluster_name" {
  type        = string
  description = "AWS EKS Cluster name"
}

variable "cluster_endpoint" {
  type        = string
  description = "AWS EKS Cluster Endpoint"
}

variable "cluster_certificate_authority_data" {
  type        = string
  description = "AWS EKS Cluster CA Data"
}
