output "endpoint" {
  value = module.db.db_instance_endpoint
}

output "address" {
  value = module.db.db_instance_address
}

output "db_instance_master_user_secret_arn" {
  value = module.db.db_instance_master_user_secret_arn
}

output "db_instance_resource_id" {
  value = module.db.db_instance_resource_id
}

output "db_instance_port" {
  value = module.db.db_instance_port
}

output "db_instance_name" {
  value = module.db.db_instance_name
}

output "db_instance_username" {
  value = module.db.db_instance_username
}

output "db_instance_availability_zone" {
  value = module.db.db_instance_availability_zone
}

output "replica_endpoint" {
  value = length(module.db_replica) > 0 ? module.db_replica[0].db_instance_endpoint : null
}

output "replica_address" {
  value = length(module.db_replica) > 0 ? module.db_replica[0].db_instance_address : null
}
