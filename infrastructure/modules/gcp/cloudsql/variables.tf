# Cloud SQL Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "instance_name" {
  description = "Base name for the Cloud SQL instance"
  type        = string
}

variable "instance_name_override" {
  description = "Override the auto-generated instance name (useful for restoring from backup)"
  type        = string
  default     = null
}

variable "database_version" {
  description = "PostgreSQL database version"
  type        = string
  default     = "POSTGRES_15"
  validation {
    condition     = can(regex("^POSTGRES_", var.database_version))
    error_message = "Database version must be a PostgreSQL version (e.g., POSTGRES_15)."
  }
}

variable "region" {
  description = "The region for the Cloud SQL instance"
  type        = string
}

variable "tier" {
  description = "The machine tier for the instance"
  type        = string
  default     = "db-f1-micro"
}

variable "activation_policy" {
  description = "Activation policy for the instance"
  type        = string
  default     = "ALWAYS"
  validation {
    condition     = contains(["ALWAYS", "NEVER"], var.activation_policy)
    error_message = "Activation policy must be either ALWAYS or NEVER."
  }
}

variable "availability_type" {
  description = "Availability type (ZONAL or REGIONAL)"
  type        = string
  default     = "ZONAL"
  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.availability_type)
    error_message = "Availability type must be either ZONAL or REGIONAL."
  }
}

variable "disk_type" {
  description = "Disk type (PD_SSD or PD_HDD)"
  type        = string
  default     = "PD_SSD"
  validation {
    condition     = contains(["PD_SSD", "PD_HDD"], var.disk_type)
    error_message = "Disk type must be either PD_SSD or PD_HDD."
  }
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 10
}

variable "disk_autoresize" {
  description = "Enable disk autoresize"
  type        = bool
  default     = true
}

variable "disk_autoresize_limit" {
  description = "Maximum disk size for autoresize in GB (0 for unlimited)"
  type        = number
  default     = 0
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "ipv4_enabled" {
  description = "Enable public IPv4 access"
  type        = bool
  default     = false
}

variable "private_network" {
  description = "VPC network for private IP"
  type        = string
}

variable "enable_private_path_for_google_cloud_services" {
  description = "Enable private path for Google Cloud services"
  type        = bool
  default     = true
}

variable "require_ssl" {
  description = "Require SSL connections"
  type        = bool
  default     = true
}

variable "authorized_networks" {
  description = "List of authorized networks"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "backup_enabled" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

variable "backup_start_time" {
  description = "Start time for daily backups (HH:MM format)"
  type        = string
  default     = "03:00"
}

variable "point_in_time_recovery_enabled" {
  description = "Enable point-in-time recovery"
  type        = bool
  default     = true
}

variable "transaction_log_retention_days" {
  description = "Number of days to retain transaction logs"
  type        = number
  default     = 7
}

variable "backup_retention_count" {
  description = "Number of backups to retain"
  type        = number
  default     = 7
}

variable "maintenance_window" {
  description = "Maintenance window configuration"
  type = object({
    day         = number
    hour        = number
    update_track = optional(string)
  })
  default = null
}

variable "database_flags" {
  description = "Database flags to set"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "query_insights_enabled" {
  description = "Enable Query Insights"
  type        = bool
  default     = false
}

variable "query_plans_per_minute" {
  description = "Number of query plans to capture per minute"
  type        = number
  default     = 5
}

variable "query_string_length" {
  description = "Maximum query string length to capture"
  type        = number
  default     = 1024
}

variable "record_application_tags" {
  description = "Record application tags in Query Insights"
  type        = bool
  default     = false
}

variable "user_labels" {
  description = "User labels for the instance"
  type        = map(string)
  default     = {}
}

variable "databases" {
  description = "List of databases to create"
  type = list(object({
    name      = string
    charset   = optional(string)
    collation = optional(string)
  }))
  default = []
}

variable "users" {
  description = "List of database users to create"
  type = list(object({
    name     = string
    password = optional(string)
    type     = optional(string)
  }))
  default = []
}

variable "create_default_user" {
  description = "Create a default database user"
  type        = bool
  default     = false
}

variable "default_user_name" {
  description = "Name of the default user"
  type        = string
  default     = "postgres"
}

variable "default_user_password" {
  description = "Password for the default user (leave null to auto-generate)"
  type        = string
  default     = null
  sensitive   = true
}

variable "private_vpc_connection" {
  description = "Private VPC connection dependency (output from network module)"
  type        = any
  default     = null
}
