output "database_username" {
  value = local.database_username
}

output "database_password" {
  value = local.database_password
  sensitive = true
}

output "database_name" {
  value = local.database_name
}
