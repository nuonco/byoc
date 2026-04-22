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
