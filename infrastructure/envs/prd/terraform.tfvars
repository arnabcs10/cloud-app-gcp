# Production Environment Configuration
# Replace the placeholder values with actual GCP project details

# ========================================
# Project Configuration
# ========================================
project_id  = "burner-arnsengu"
region      = "us-central1"                 # Primary region for resources
environment = "prd"

# ========================================
# Network Configuration
# ========================================
vpc_name         = "cloud-app-vpc-prd"
gke_subnet_cidr  = "10.0.0.0/24"           # GKE nodes subnet
gke_pods_cidr    = "10.1.0.0/16"           # GKE pods secondary range
gke_services_cidr = "10.2.0.0/16"          # GKE services secondary range

# ========================================
# GKE Cluster Configuration
# ========================================
gke_cluster_name           = "cloud-app-gke-prd"
gke_node_pool_machine_type = "e2-standard-4"  # 4 vCPU, 16GB RAM
gke_node_pool_min_count    = 2                # Minimum nodes for HA
gke_node_pool_max_count    = 3               # Maximum nodes for autoscaling
gke_master_ipv4_cidr       = "172.16.0.0/28"  # GKE master CIDR

# Master Authorized Networks - Add IP ranges for kubectl access
master_authorized_networks = [
  # TODO: Add authorized networks for GKE API access
  # {
  #   cidr_block   = "IP_ADDRESS/32"
  #   display_name = "IP_NAME"
  # },
]

# ========================================
# Cloud SQL Configuration
# ========================================
cloudsql_instance_name    = "cloud-app-postgres-prd"
cloudsql_tier             = "db-custom-2-7680"  # 2 vCPU, 7.5GB RAM
cloudsql_disk_size        = 100                 # 100GB SSD
cloudsql_database_version = "POSTGRES_15"
cloudsql_availability_type = "REGIONAL"         # High availability

# Database names to create
database_names = [
  "voting_app",
  "results_app"
]

# ========================================
# Common Labels
# ========================================
labels = {
  environment = "production"
  managed_by  = "terraform"
  project     = "cloud-app-gcp"
  team        = "devops"                        
  cost_center = "engineering"                  
}

# ========================================
# Firewall Configuration
# ========================================
# SSH access - Add IP ranges if SSH access is needed
allowed_ssh_cidrs = [
  # TODO: Add IP ranges for SSH access (if needed)
  # _IP_ADDRESS/32",
]

# ========================================
# IMPORTANT NOTES: Veriables need to configure per project
# ========================================
# 1. Replace "gcp-project-id" with actual GCP project ID
# 2. Update master_authorized_networks with IP addresses for kubectl access
# 3. Review and adjust machine types and autoscaling limits based on needs
# 4. Ensure you have enabled required GCP APIs:
#    - compute.googleapis.com
#    - container.googleapis.com
#    - sqladmin.googleapis.com
#    - servicenetworking.googleapis.com
#    - cloudresourcemanager.googleapis.com
#    - iam.googleapis.com

