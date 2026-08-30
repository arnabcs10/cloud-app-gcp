# Cloud SQL Module - Production Environment

module "cloudsql" {
  source = "../../modules/gcp/cloudsql"

  project_id      = var.project_id
  instance_name   = var.cloudsql_instance_name
  database_version = var.cloudsql_database_version
  region          = var.region

  # Instance Configuration
  tier              = var.cloudsql_tier
  activation_policy = "ALWAYS"
  availability_type = var.cloudsql_availability_type # REGIONAL for HA

  # Disk Configuration
  disk_type              = "PD_SSD"
  disk_size              = var.cloudsql_disk_size
  disk_autoresize        = true
  disk_autoresize_limit  = 500 # Max 500GB

  # Security
  deletion_protection = true

  # Network Configuration
  ipv4_enabled    = false # Private IP only
  private_network = module.network.vpc_self_link
  enable_private_path_for_google_cloud_services = true

  # No public authorized networks for production
  authorized_networks = []

  # Backup Configuration
  backup_enabled                 = true
  backup_start_time              = "02:00" # 2 AM UTC
  point_in_time_recovery_enabled = true
  transaction_log_retention_days = 7
  backup_retention_count         = 7 # Keep 7 backups

  # Maintenance Window
  maintenance_window = {
    day          = 7 # Sunday
    hour         = 3 # 3 AM UTC
    update_track = "stable"
  }

  # Database Flags for Production Optimization
  database_flags = [
    {
      name  = "max_connections"
      value = "200"
    },
    {
      name  = "shared_buffers"
      value = "393216" # ~3GB in 8KB blocks (adjust based on tier)
    },
    {
      name  = "effective_cache_size"
      value = "1179648" # ~9GB in 8KB blocks
    },
    {
      name  = "maintenance_work_mem"
      value = "1048576" # 1GB in KB
    },
    {
      name  = "checkpoint_completion_target"
      value = "0.9"
    },
    {
      name  = "wal_buffers"
      value = "16384" # 16MB in 8KB blocks
    },
    {
      name  = "default_statistics_target"
      value = "100"
    },
    {
      name  = "random_page_cost"
      value = "1.1" # SSD optimization
    },
    {
      name  = "effective_io_concurrency"
      value = "200" # SSD optimization
    },
    {
      name  = "work_mem"
      value = "5242" # ~5MB in KB
    },
    {
      name  = "min_wal_size"
      value = "1024" # 1GB in MB
    },
    {
      name  = "max_wal_size"
      value = "4096" # 4GB in MB
    },
    {
      name  = "log_min_duration_statement"
      value = "1000" # Log queries > 1 second
    },
    {
      name  = "log_connections"
      value = "on"
    },
    {
      name  = "log_disconnections"
      value = "on"
    },
    {
      name  = "log_lock_waits"
      value = "on"
    },
    {
      name  = "log_temp_files"
      value = "0" # Log all temp files
    }
  ]

  # Query Insights for Performance Monitoring
  query_insights_enabled  = true
  query_plans_per_minute  = 5
  query_string_length     = 4096
  record_application_tags = true

  # User Labels
  user_labels = merge(
    var.labels,
    {
      instance_name = var.cloudsql_instance_name
      database_type = "postgresql"
    }
  )

  # Databases to Create
  databases = [
    for db_name in var.database_names : {
      name      = db_name
      charset   = "UTF8"
      collation = "en_US.UTF8"
    }
  ]

  # Additional Database Users (beyond default postgres user)
  users = [
    {
      name = "voting_app_user"
      # Password will be auto-generated and stored in outputs (use Secret Manager in production)
    },
    {
      name = "results_app_user"
    },
    {
      name = "worker_app_user"
    }
  ]

  # Create default postgres user with auto-generated password
  create_default_user = true
  default_user_name   = "postgres"
  # default_user_password is auto-generated (null)

  # Dependency on network module for private service connection
  private_vpc_connection = module.network.private_vpc_connection
  depends_on            = [module.network]
}
