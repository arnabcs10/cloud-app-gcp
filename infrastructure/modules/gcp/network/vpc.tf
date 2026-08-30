# VPC Network Configuration

resource "google_compute_network" "vpc" {
  name                            = var.vpc_name
  auto_create_subnetworks         = false
  routing_mode                    = var.routing_mode
  delete_default_routes_on_create = var.delete_default_routes
  description                     = var.vpc_description
  project                         = var.project_id

  # Enable or disable VPC flow logs at network level
  mtu = var.mtu
}

# Reserve a global internal IP range for Private Service Connection
resource "google_compute_global_address" "private_ip_range" {
  count         = var.enable_private_service_connection ? 1 : 0
  name          = "${var.vpc_name}-private-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.private_ip_range_prefix_length
  network       = google_compute_network.vpc.id
  project       = var.project_id
}

# Private VPC Connection for managed services (Cloud SQL, etc.)
resource "google_service_networking_connection" "private_vpc_connection" {
  count                   = var.enable_private_service_connection ? 1 : 0
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range[0].name]

  depends_on = [google_compute_global_address.private_ip_range]
}
