# Subnet Configuration

resource "google_compute_subnetwork" "subnets" {
  for_each = { for subnet in var.subnets : subnet.name => subnet }

  name                     = each.value.name
  ip_cidr_range            = each.value.ip_cidr_range
  region                   = each.value.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = lookup(each.value, "private_ip_google_access", true)
  description              = lookup(each.value, "description", "")
  project                  = var.project_id

  # Secondary IP ranges for GKE pods and services
  dynamic "secondary_ip_range" {
    for_each = lookup(each.value, "secondary_ip_ranges", [])
    content {
      range_name    = secondary_ip_range.value.range_name
      ip_cidr_range = secondary_ip_range.value.ip_cidr_range
    }
  }

  # VPC Flow Logs configuration
  dynamic "log_config" {
    for_each = lookup(each.value, "enable_flow_logs", false) ? [1] : []
    content {
      aggregation_interval = lookup(each.value, "flow_logs_interval", "INTERVAL_5_SEC")
      flow_sampling        = lookup(each.value, "flow_logs_sampling", 0.5)
      metadata             = lookup(each.value, "flow_logs_metadata", "INCLUDE_ALL_METADATA")
    }
  }
}
