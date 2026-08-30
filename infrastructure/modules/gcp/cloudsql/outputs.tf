# Cloud SQL Module Outputs

output "instance_id" {
  description = "The ID of the Cloud SQL instance"
  value       = google_sql_database_instance.postgres.id
}

output "instance_name" {
  description = "The name of the Cloud SQL instance"
  value       = google_sql_database_instance.postgres.name
}

output "instance_connection_name" {
  description = "The connection name for the instance"
  value       = google_sql_database_instance.postgres.connection_name
}

output "instance_self_link" {
  description = "The URI of the instance"
  value       = google_sql_database_instance.postgres.self_link
}

output "instance_ip_address" {
  description = "The first private IPv4 address assigned"
  value       = length(google_sql_database_instance.postgres.ip_address) > 0 ? google_sql_database_instance.postgres.ip_address[0].ip_address : null
}

output "instance_private_ip_address" {
  description = "The private IP address assigned"
  value = try(
    [for ip in google_sql_database_instance.postgres.ip_address : ip.ip_address if ip.type == "PRIVATE"][0],
    null
  )
}

output "instance_public_ip_address" {
  description = "The public IP address assigned"
  value = try(
    [for ip in google_sql_database_instance.postgres.ip_address : ip.ip_address if ip.type == "PRIMARY"][0],
    null
  )
}

output "instance_server_ca_cert" {
  description = "The CA certificate for the instance"
  value       = google_sql_database_instance.postgres.server_ca_cert
  sensitive   = true
}

output "databases" {
  description = "Map of database details"
  value = {
    for k, v in google_sql_database.databases : k => {
      id        = v.id
      name      = v.name
      charset   = v.charset
      collation = v.collation
    }
  }
}

output "database_names" {
  description = "List of database names"
  value       = [for db in google_sql_database.databases : db.name]
}

output "users" {
  description = "Map of user details (passwords excluded)"
  value = {
    for k, v in google_sql_user.users : k => {
      id   = v.id
      name = v.name
      type = v.type
    }
  }
}

output "user_names" {
  description = "List of user names"
  value       = [for user in google_sql_user.users : user.name]
}

output "default_user_name" {
  description = "The default user name (if created)"
  value       = var.create_default_user ? google_sql_user.default_user[0].name : null
}

output "default_user_password" {
  description = "The default user password (if auto-generated)"
  value       = var.create_default_user && var.default_user_password == null ? random_password.default_user_password[0].result : null
  sensitive   = true
}

output "connection_info" {
  description = "Connection information for the database"
  value = {
    instance_connection_name = google_sql_database_instance.postgres.connection_name
    private_ip              = try([for ip in google_sql_database_instance.postgres.ip_address : ip.ip_address if ip.type == "PRIVATE"][0], null)
    public_ip               = var.ipv4_enabled ? try([for ip in google_sql_database_instance.postgres.ip_address : ip.ip_address if ip.type == "PRIMARY"][0], null) : null
  }
}
