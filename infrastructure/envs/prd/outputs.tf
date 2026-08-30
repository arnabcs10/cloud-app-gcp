# Production Environment Outputs

# ========================================
# Network Outputs
# ========================================

output "vpc_id" {
  description = "The ID of the VPC network"
  value       = module.network.vpc_id
}

output "vpc_name" {
  description = "The name of the VPC network"
  value       = module.network.vpc_name
}

output "subnet_ids" {
  description = "Map of subnet IDs"
  value       = module.network.subnet_ids
}

output "cloud_nat_id" {
  description = "The ID of Cloud NAT"
  value       = module.network.cloud_nat_id
}

# ========================================
# GKE Outputs
# ========================================

output "gke_cluster_name" {
  description = "The name of the GKE cluster"
  value       = module.gke.cluster_name
}

output "gke_cluster_endpoint" {
  description = "The endpoint for the GKE cluster"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "gke_cluster_ca_certificate" {
  description = "The cluster CA certificate (base64 encoded)"
  value       = module.gke.cluster_ca_certificate
  sensitive   = true
}

output "gke_kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = module.gke.kubectl_config_command
}

output "gke_workload_identity_pool" {
  description = "Workload Identity pool for the cluster"
  value       = module.gke.workload_identity_pool
}

output "gke_workload_identity_service_accounts" {
  description = "Map of Workload Identity service accounts"
  value       = module.gke.workload_identity_service_accounts
  sensitive   = true
}

# ========================================
# Cloud SQL Outputs
# ========================================

output "cloudsql_instance_name" {
  description = "The name of the Cloud SQL instance"
  value       = module.cloudsql.instance_name
}

output "cloudsql_instance_connection_name" {
  description = "The connection name for Cloud SQL"
  value       = module.cloudsql.instance_connection_name
}

output "cloudsql_private_ip_address" {
  description = "The private IP address of Cloud SQL"
  value       = module.cloudsql.instance_private_ip_address
}

output "cloudsql_database_names" {
  description = "List of created database names"
  value       = module.cloudsql.database_names
}

output "cloudsql_default_user_password" {
  description = "Auto-generated password for default postgres user"
  value       = module.cloudsql.default_user_password
  sensitive   = true
}

output "cloudsql_connection_info" {
  description = "Connection information for Cloud SQL"
  value       = module.cloudsql.connection_info
  sensitive   = true
}

# ========================================
# IAM Outputs
# ========================================

output "service_account_emails" {
  description = "Map of service account emails"
  value       = module.iam.service_account_emails
}

output "gke_node_service_account_email" {
  description = "Email of the GKE node service account"
  value       = module.iam.gke_node_service_account_email
}

# ========================================
# Deployment Information
# ========================================

output "deployment_info" {
  description = "Production deployment information"
  value = {
    environment = var.environment
    project_id  = var.project_id
    region      = var.region
    vpc_name    = module.network.vpc_name
    gke_cluster = module.gke.cluster_name
    cloudsql_instance = module.cloudsql.instance_name
  }
}

# ========================================
# Connection Instructions
# ========================================

output "connection_instructions" {
  description = "Instructions for connecting to resources"
  value = <<-EOT
    
    ========================================
    Production Environment Connection Guide
    ========================================
    
    1. Configure kubectl:
       ${module.gke.kubectl_config_command}
    
    2. Verify cluster access:
       kubectl cluster-info
       kubectl get nodes
    
    3. Cloud SQL Connection (from GKE pod with Workload Identity):
       Instance: ${module.cloudsql.instance_connection_name}
       Private IP: ${module.cloudsql.instance_private_ip_address}
       
       Using Cloud SQL Proxy:
       cloud_sql_proxy -instances=${module.cloudsql.instance_connection_name}=tcp:5432
    
    4. Database Access:
       psql -h ${module.cloudsql.instance_private_ip_address} -U postgres -d voting_app
    
    ========================================
  EOT
}
