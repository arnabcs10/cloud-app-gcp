# Private Service Connection Configuration
# Note: This is typically created at the VPC level, but we include a reference here
# for documentation purposes. The actual resource should be created in the network module.

# This module expects the private service connection to be passed as a dependency
# through the var.private_vpc_connection variable

# Example of how to create if not using network module:
# resource "google_compute_global_address" "private_ip_address" {
#   name          = "${var.instance_name}-private-ip"
#   purpose       = "VPC_PEERING"
#   address_type  = "INTERNAL"
#   prefix_length = 16
#   network       = var.vpc_network
#   project       = var.project_id
# }

# resource "google_service_networking_connection" "private_vpc_connection" {
#   network                 = var.vpc_network
#   service                 = "servicenetworking.googleapis.com"
#   reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
# }
