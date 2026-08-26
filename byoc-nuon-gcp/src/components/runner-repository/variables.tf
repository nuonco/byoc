variable "install_id" {
  type = string
}

variable "org_id" {
  type = string
}

variable "project_id" {
  type = string
}

variable "region" {
  type        = string
  description = "The install region. The runner repository is regional, unlike the AWS ECR Public equivalent which is global."
}
