output "create_db_sql_statement_arborist" {
  value = join(" ", [
    module.arborist-db.create_db_sql_statement,
    module.argo-db.create_db_sql_statement
  ]
}

output "create_user_sql_statement_arborist" {
  value = local.create_user_statement
}
