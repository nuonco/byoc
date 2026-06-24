variable "install_id" {
  type = string
}

variable "org_id" {
  type = string
}

variable "region" {
  type        = string
  description = "The install region. ECR Public itself is provisioned in us-east-1, but the install region is used for tagging and consistency with the rest of the install."
}

variable "ecr" {
  type = object({
    id  = string
    arn = string
  })
  description = "The private app ECR details passed through from the sandbox. Not used for the public runner repo, but kept for parity with the management component and to make the relationship explicit."
}
