variable "install_id" {
  type = string
}

variable "project_id" {
  type = string
}

variable "cloudsql_instance_name" {
  type = string
}

# The install's runner service account (from the install-stack outputs). Granted
# token-creator on the ctl-api SA so maintenance actions running on the runner
# can impersonate ctl-api — e.g. mint an OIDC token with ctl-api's identity to
# verify the AWS S3 install-templates federation (s3_bucket inspect action).
variable "runner_service_account_email" {
  type = string
}
