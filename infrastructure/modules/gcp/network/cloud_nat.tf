# Cloud NAT Configuration

# Cloud Router for NAT
resource "google_compute_router" "router" {
  count   = var.cloud_nat_config.enabled ? 1 : 0
  name    = var.cloud_nat_config.router_name != null ? var.cloud_nat_config.router_name : "${var.vpc_name}-router"
  region  = var.cloud_nat_config.region
  network = google_compute_network.vpc.id
  project = var.project_id

  bgp {
    asn = var.cloud_router_asn
  }
}

# Cloud NAT for outbound internet access
resource "google_compute_router_nat" "nat" {
  count  = var.cloud_nat_config.enabled ? 1 : 0
  name   = var.cloud_nat_config.name != null ? var.cloud_nat_config.name : "${var.vpc_name}-nat"
  router = google_compute_router.router[0].name
  region = var.cloud_nat_config.region

  nat_ip_allocate_option             = lookup(var.cloud_nat_config, "nat_ip_allocate_option", "AUTO_ONLY")
  source_subnetwork_ip_ranges_to_nat = lookup(var.cloud_nat_config, "source_subnetwork_ip_ranges_to_nat", "ALL_SUBNETWORKS_ALL_IP_RANGES")

  # Port allocation settings
  min_ports_per_vm                    = lookup(var.cloud_nat_config, "min_ports_per_vm", 64)
  max_ports_per_vm                    = lookup(var.cloud_nat_config, "max_ports_per_vm", 65536)
  enable_dynamic_port_allocation      = lookup(var.cloud_nat_config, "enable_dynamic_port_allocation", false)
  enable_endpoint_independent_mapping = lookup(var.cloud_nat_config, "enable_endpoint_independent_mapping", true)

  # Logging configuration
  dynamic "log_config" {
    for_each = lookup(var.cloud_nat_config, "log_config", null) != null ? [var.cloud_nat_config.log_config] : []
    content {
      enable = log_config.value.enable
      filter = log_config.value.filter
    }
  }
}
