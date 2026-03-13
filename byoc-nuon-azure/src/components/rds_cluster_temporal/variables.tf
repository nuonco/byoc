variable "nuon_id" {
  type = string
}

variable "region" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "identifier" {
  type = string
}

variable "port" {
  type    = string
  default = "5432"
}

variable "instance_class" {
  type    = string
  default = "GP_Standard_D8ds_v5"
}

variable "db_name" {
  type = string
}

variable "db_user" {
  type = string
}

variable "allocated_storage" {
  type    = string
  default = "500"
}

variable "backup_retention_period" {
  type    = string
  default = "7"
}

variable "zone" {
  type    = string
  default = "1"
}

# Compatibility vars retained from the AWS implementation.
variable "iam_database_authentication_enabled" {
  type    = string
  default = "true"
}

variable "deletion_protection" {
  type    = string
  default = "false"
}

variable "apply_immediately" {
  type    = string
  default = "true"
}

variable "multi_az" {
  type    = string
  default = "false"
}

variable "skip_final_snapshot" {
  type    = string
  default = "false"
}

variable "storage_encrypted" {
  type    = string
  default = "true"
}

variable "maintenance_window" {
  type    = string
  default = "Mon:00:00-Mon:03:00"
}

variable "backup_window" {
  type    = string
  default = "03:00-06:00"
}
