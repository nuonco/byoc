variable "install_id" {
  type = string
}

variable "project_id" {
  type = string
}

variable "service_account_email" {
  type        = string
  description = "Stack-created service account (install stack custom_sa_emails output)."
}
