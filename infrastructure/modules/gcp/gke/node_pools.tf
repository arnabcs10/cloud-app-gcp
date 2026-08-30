# GKE Node Pool Configuration

resource "google_container_node_pool" "pools" {
  for_each = { for pool in var.node_pools : pool.name => pool }

  name     = each.value.name
  location = var.regional_cluster ? var.region : var.zone
  cluster  = google_container_cluster.primary.name
  project  = var.project_id

  # Node count configuration
  initial_node_count = lookup(each.value, "initial_node_count", 1)

  # Autoscaling configuration
  dynamic "autoscaling" {
    for_each = lookup(each.value, "autoscaling", null) != null ? [each.value.autoscaling] : []
    content {
      min_node_count       = autoscaling.value.min_node_count
      max_node_count       = autoscaling.value.max_node_count
      location_policy      = lookup(autoscaling.value, "location_policy", "BALANCED")
      total_min_node_count = lookup(autoscaling.value, "total_min_node_count", null)
      total_max_node_count = lookup(autoscaling.value, "total_max_node_count", null)
    }
  }

  # Management configuration
  management {
    auto_repair  = lookup(each.value, "auto_repair", true)
    auto_upgrade = lookup(each.value, "auto_upgrade", true)
  }

  # Node configuration
  node_config {
    machine_type = lookup(each.value, "machine_type", "e2-medium")
    disk_size_gb = lookup(each.value, "disk_size_gb", 100)
    disk_type    = lookup(each.value, "disk_type", "pd-standard")
    image_type   = lookup(each.value, "image_type", "COS_CONTAINERD")
    preemptible  = lookup(each.value, "preemptible", false)
    spot         = lookup(each.value, "spot", false)

    # Service account
    service_account = lookup(each.value, "service_account", null)

    # OAuth scopes
    oauth_scopes = lookup(each.value, "oauth_scopes", [
      "https://www.googleapis.com/auth/cloud-platform"
    ])

    # Labels
    labels = merge(
      lookup(each.value, "labels", {}),
      {
        node_pool = each.value.name
      }
    )

    # Metadata
    metadata = merge(
      lookup(each.value, "metadata", {}),
      {
        disable-legacy-endpoints = "true"
      }
    )

    # Tags
    tags = lookup(each.value, "tags", [])

    # Workload Identity configuration
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Shielded instance configuration
    dynamic "shielded_instance_config" {
      for_each = var.enable_shielded_nodes ? [1] : []
      content {
        enable_secure_boot          = true
        enable_integrity_monitoring = true
      }
    }

    # Taints
    dynamic "taint" {
      for_each = lookup(each.value, "taints", [])
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }

    # GCE persistent disk CSI driver
    dynamic "gcfs_config" {
      for_each = lookup(each.value, "enable_gcfs", false) ? [1] : []
      content {
        enabled = true
      }
    }

    # Guest accelerator (GPU)
    dynamic "guest_accelerator" {
      for_each = lookup(each.value, "accelerator", null) != null ? [each.value.accelerator] : []
      content {
        type  = guest_accelerator.value.type
        count = guest_accelerator.value.count
        gpu_partition_size = lookup(guest_accelerator.value, "gpu_partition_size", null)

        dynamic "gpu_sharing_config" {
          for_each = lookup(guest_accelerator.value, "gpu_sharing_config", null) != null ? [guest_accelerator.value.gpu_sharing_config] : []
          content {
            gpu_sharing_strategy       = gpu_sharing_config.value.gpu_sharing_strategy
            max_shared_clients_per_gpu = gpu_sharing_config.value.max_shared_clients_per_gpu
          }
        }
      }
    }
  }

  # Upgrade settings
  dynamic "upgrade_settings" {
    for_each = lookup(each.value, "upgrade_settings", null) != null ? [each.value.upgrade_settings] : []
    content {
      max_surge       = lookup(upgrade_settings.value, "max_surge", 1)
      max_unavailable = lookup(upgrade_settings.value, "max_unavailable", 0)
      strategy        = lookup(upgrade_settings.value, "strategy", "SURGE")

      dynamic "blue_green_settings" {
        for_each = lookup(upgrade_settings.value, "blue_green_settings", null) != null ? [upgrade_settings.value.blue_green_settings] : []
        content {
          node_pool_soak_duration = lookup(blue_green_settings.value, "node_pool_soak_duration", null)

          standard_rollout_policy {
            batch_percentage    = lookup(blue_green_settings.value, "batch_percentage", null)
            batch_node_count    = lookup(blue_green_settings.value, "batch_node_count", null)
            batch_soak_duration = lookup(blue_green_settings.value, "batch_soak_duration", null)
          }
        }
      }
    }
  }

  timeouts {
    create = var.node_pool_timeout_create
    update = var.node_pool_timeout_update
    delete = var.node_pool_timeout_delete
  }
}
