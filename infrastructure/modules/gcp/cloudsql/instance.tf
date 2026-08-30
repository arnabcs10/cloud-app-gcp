# Cloud SQL PostgreSQL Instance Configuration

resource "random_id" "db_name_suffix" {
  byte_length = 4
}

resource "google_sql_database_instance" "postgres" {
  name             = var.instance_name_override != null ? var.instance_name_override : "${var.instance_name}-${random_id.db_name_suffix.hex}"
  database_version = var.database_version
  region           = var.region
  project          = var.project_id

  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    activation_policy = var.activation_policy
    availability_type = var.availability_type
    disk_type         = var.disk_type
    disk_size         = var.disk_size
    disk_autoresize       = var.disk_autoresize
    disk_autoresize_limit = var.disk_autoresize_limit

    # IP configuration
    ip_configuration {
      ipv4_enabled                                  = var.ipv4_enabled
      private_network                               = var.private_network
      enable_private_path_for_google_cloud_services = var.enable_private_path_for_google_cloud_services
      # require_ssl                                   = var.require_ssl

      # Authorized networks
      dynamic "authorized_networks" {
        for_each = var.authorized_networks
        content {
          name  = authorized_networks.value.name
          value = authorized_networks.value.value
        }
      }
    }

    # Backup configuration
    backup_configuration {
      enabled                        = var.backup_enabled
      start_time                     = var.backup_start_time
      point_in_time_recovery_enabled = var.point_in_time_recovery_enabled
      transaction_log_retention_days = var.transaction_log_retention_days
      backup_retention_settings {
        retained_backups = var.backup_retention_count
        retention_unit   = "COUNT"
      }
    }

    # Maintenance window
    dynamic "maintenance_window" {
      for_each = var.maintenance_window != null ? [var.maintenance_window] : []
      content {
        day          = maintenance_window.value.day
        hour         = maintenance_window.value.hour
        update_track = lookup(maintenance_window.value, "update_track", "stable")
      }
    }

    # Database flags
    dynamic "database_flags" {
      for_each = var.database_flags
      content {
        name  = database_flags.value.name
        value = database_flags.value.value
      }
    }

    # Insights config
    insights_config {
      query_insights_enabled  = var.query_insights_enabled
      query_plans_per_minute  = var.query_plans_per_minute
      query_string_length     = var.query_string_length
      record_application_tags = var.record_application_tags
    }

    # User labels
    user_labels = var.user_labels
  }

  depends_on = [var.private_vpc_connection]
}

# Database creation
resource "google_sql_database" "databases" {
  for_each = { for db in var.databases : db.name => db }

  name      = each.value.name
  instance  = google_sql_database_instance.postgres.name
  charset   = lookup(each.value, "charset", "UTF8")
  collation = lookup(each.value, "collation", "en_US.UTF8")
  project   = var.project_id
}

# Database users
resource "google_sql_user" "users" {
  for_each = { for user in var.users : user.name => user }

  name     = each.value.name
  instance = google_sql_database_instance.postgres.name
  password = lookup(each.value, "password", null)
  type     = lookup(each.value, "type", "BUILT_IN")
  project  = var.project_id
}

# Generate random password for default user if not provided
resource "random_password" "default_user_password" {
  count   = var.create_default_user && var.default_user_password == null ? 1 : 0
  length  = 32
  special = true
}

resource "google_sql_user" "default_user" {
  count = var.create_default_user ? 1 : 0

  name     = var.default_user_name
  instance = google_sql_database_instance.postgres.name
  password = var.default_user_password != null ? var.default_user_password : random_password.default_user_password[0].result
  project  = var.project_id
}
