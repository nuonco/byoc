variable "arn" {
  type        = string
  description = "the arn of the AWS Secret Manaer Secret you want to copy"
}

variable "namespace" {
  type        = string
  description = "the namespace to create the secret in"
}

variable "name" {
  type        = string
  description = "the name of secret"
}
