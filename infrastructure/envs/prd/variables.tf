# Production Environment Variables

# Project Configuration
variable "project_id" {
  description = "The GCP project ID for production environment"
  type        = string
}

variable "region" {
  description = "The primary GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prd"
}

# Network Variables
variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "cloud-app-vpc-prd"
}

variable "gke_subnet_cidr" {
  description = "CIDR range for GKE subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "gke_pods_cidr" {
  description = "CIDR range for GKE pods"
  type        = string
  default     = "10.1.0.0/16"
}

variable "gke_services_cidr" {
  description = "CIDR range for GKE services"
  type        = string
  default     = "10.2.0.0/16"
}

# GKE Variables
variable "gke_cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "cloud-app-gke-prd"
}

variable "gke_node_pool_machine_type" {
  description = "Machine type for GKE node pool"
  type        = string
  default     = "e2-standard-4"
}

variable "gke_node_pool_min_count" {
  description = "Minimum number of nodes in the node pool"
  type        = number
  default     = 2
}

variable "gke_node_pool_max_count" {
  description = "Maximum number of nodes in the node pool"
  type        = number
  default     = 10
}

variable "gke_master_ipv4_cidr" {
  description = "CIDR range for GKE master"
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "List of master authorized networks for GKE API access"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

# Cloud SQL Variables
variable "cloudsql_instance_name" {
  description = "Name of the Cloud SQL instance"
  type        = string
  default     = "cloud-app-postgres-prd"
}

variable "cloudsql_tier" {
  description = "Machine tier for Cloud SQL"
  type        = string
  default     = "db-custom-2-7680" # 2 vCPU, 7.5GB RAM
}

variable "cloudsql_disk_size" {
  description = "Disk size in GB for Cloud SQL"
  type        = number
  default     = 100
}

variable "cloudsql_database_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "POSTGRES_15"
}

variable "cloudsql_availability_type" {
  description = "Availability type (ZONAL or REGIONAL)"
  type        = string
  default     = "REGIONAL" # High availability for production
}

variable "database_names" {
  description = "List of database names to create"
  type        = list(string)
  default     = ["voting_app", "results_app"]
}

# Common Labels
variable "labels" {
  description = "Common labels to apply to all resources"
  type        = map(string)
  default = {
    environment = "production"
    managed_by  = "terraform"
    project     = "cloud-app-gcp"
  }
}

# Firewall Configuration
variable "allowed_ssh_cidrs" {
  description = "CIDR ranges allowed for SSH access"
  type        = list(string)
  default     = [] # Add IP ranges in terraform.tfvars
}
