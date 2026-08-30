# GKE Module Outputs

output "cluster_id" {
  description = "The ID of the GKE cluster"
  value       = google_container_cluster.primary.id
}

output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "The endpoint for the GKE cluster"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "The cluster CA certificate"
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_master_version" {
  description = "The Kubernetes master version"
  value       = google_container_cluster.primary.master_version
}

output "cluster_location" {
  description = "The location of the cluster"
  value       = google_container_cluster.primary.location
}

output "cluster_self_link" {
  description = "The self link of the cluster"
  value       = google_container_cluster.primary.self_link
}

output "cluster_region" {
  description = "The region of the cluster"
  value       = var.regional_cluster ? var.region : null
}

output "cluster_zone" {
  description = "The zone of the cluster"
  value       = var.regional_cluster ? null : var.zone
}

output "node_pools" {
  description = "Map of node pool details"
  value = {
    for k, v in google_container_node_pool.pools : k => {
      id           = v.id
      name         = v.name
      version      = v.version
      node_count   = v.node_count
      instance_urls = v.managed_instance_group_urls
    }
  }
}

output "node_pool_names" {
  description = "List of node pool names"
  value       = [for pool in google_container_node_pool.pools : pool.name]
}

output "workload_identity_service_accounts" {
  description = "Map of Workload Identity service account details"
  value = {
    for k, v in google_service_account.workload_identity : k => {
      email       = v.email
      name        = v.name
      account_id  = v.account_id
      unique_id   = v.unique_id
    }
  }
}

output "workload_identity_pool" {
  description = "The Workload Identity pool for the cluster"
  value       = "${var.project_id}.svc.id.goog"
}

output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region=${var.regional_cluster ? var.region : var.zone} --project=${var.project_id}"
}
