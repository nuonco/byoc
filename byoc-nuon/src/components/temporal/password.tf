locals {
  db_username = jsondecode(data.aws_secretsmanager_secret_version.db_instance_password.secret_string).username
  db_password = jsondecode(data.aws_secretsmanager_secret_version.db_instance_password.secret_string).password
}

data "aws_secretsmanager_secret_version" "db_instance_password" {
  secret_id = var.db_instance_master_user_secret_arn
}
