# Firewall Rules Configuration

resource "google_compute_firewall" "rules" {
  for_each = { for rule in var.firewall_rules : rule.name => rule }

  name        = each.value.name
  description = lookup(each.value, "description", "")
  network     = google_compute_network.vpc.id
  project     = var.project_id
  direction   = each.value.direction
  priority    = lookup(each.value, "priority", 1000)

  # Source configuration
  source_ranges           = lookup(each.value, "ranges", null)
  source_tags             = lookup(each.value, "source_tags", null)
  source_service_accounts = lookup(each.value, "source_service_accounts", null)

  # Target configuration
  target_tags             = lookup(each.value, "target_tags", null)
  target_service_accounts = lookup(each.value, "target_service_accounts", null)

  # Allow rules
  dynamic "allow" {
    for_each = lookup(each.value, "allow", [])
    content {
      protocol = allow.value.protocol
      ports    = lookup(allow.value, "ports", null)
    }
  }

  # Deny rules
  dynamic "deny" {
    for_each = lookup(each.value, "deny", [])
    content {
      protocol = deny.value.protocol
      ports    = lookup(deny.value, "ports", null)
    }
  }

  # Logging configuration
  dynamic "log_config" {
    for_each = lookup(each.value, "log_config", null) != null ? [each.value.log_config] : []
    content {
      metadata = log_config.value.metadata
    }
  }
}
