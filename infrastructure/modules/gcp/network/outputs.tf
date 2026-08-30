# Network Module Outputs

output "vpc_id" {
  description = "The ID of the VPC network"
  value       = google_compute_network.vpc.id
}

output "vpc_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.vpc.name
}

output "vpc_self_link" {
  description = "The URI of the VPC network"
  value       = google_compute_network.vpc.self_link
}

output "subnets" {
  description = "Map of subnet details"
  value = {
    for k, v in google_compute_subnetwork.subnets : k => {
      id                = v.id
      name              = v.name
      self_link         = v.self_link
      ip_cidr_range     = v.ip_cidr_range
      region            = v.region
      gateway_address   = v.gateway_address
      secondary_ip_range = v.secondary_ip_range
    }
  }
}

output "subnet_ids" {
  description = "Map of subnet names to IDs"
  value       = { for k, v in google_compute_subnetwork.subnets : k => v.id }
}

output "subnet_self_links" {
  description = "Map of subnet names to self links"
  value       = { for k, v in google_compute_subnetwork.subnets : k => v.self_link }
}

output "firewall_rules" {
  description = "Map of firewall rule details"
  value = {
    for k, v in google_compute_firewall.rules : k => {
      id        = v.id
      name      = v.name
      self_link = v.self_link
    }
  }
}

output "cloud_router_id" {
  description = "The ID of the Cloud Router"
  value       = var.cloud_nat_config.enabled ? google_compute_router.router[0].id : null
}

output "cloud_router_name" {
  description = "The name of the Cloud Router"
  value       = var.cloud_nat_config.enabled ? google_compute_router.router[0].name : null
}

output "cloud_nat_id" {
  description = "The ID of the Cloud NAT"
  value       = var.cloud_nat_config.enabled ? google_compute_router_nat.nat[0].id : null
}

output "cloud_nat_name" {
  description = "The name of the Cloud NAT"
  value       = var.cloud_nat_config.enabled ? google_compute_router_nat.nat[0].name : null
}

output "private_vpc_connection" {
  description = "The private VPC connection for managed services"
  value       = var.enable_private_service_connection ? google_service_networking_connection.private_vpc_connection[0].network : null
}

output "private_ip_range_name" {
  description = "The name of the private IP range for service networking"
  value       = var.enable_private_service_connection ? google_compute_global_address.private_ip_range[0].name : null
}
