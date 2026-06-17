output "db_host" {
  value = module.rds.db_instance_address
}

output "db_port" {
  value = 5432
}

output "db_name" {
  value = var.db_name
}

output "db_username" {
  value = var.db_username
}

output "db_password" {
  value     = random_password.db.result
  sensitive = true
}
