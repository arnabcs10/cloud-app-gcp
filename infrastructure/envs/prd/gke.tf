# GKE Module - Production Environment

module "gke" {
  source = "../../modules/gcp/gke"

  project_id    = var.project_id
  cluster_name  = var.gke_cluster_name
  region        = var.region
  regional_cluster = true # Regional cluster for high availability

  # Network Configuration
  network    = module.network.vpc_self_link
  subnetwork = module.network.subnet_self_links["gke-subnet-${var.region}"]

  # Secondary IP ranges for pods and services
  pods_secondary_range_name     = "gke-pods-${var.region}"
  services_secondary_range_name = "gke-services-${var.region}"

  # Private Cluster Configuration
  enable_private_cluster      = true
  enable_private_endpoint     = false # Keep public endpoint for management
  master_ipv4_cidr_block      = var.gke_master_ipv4_cidr
  enable_master_global_access = true

  # Master Authorized Networks
  master_authorized_networks = var.master_authorized_networks

  # Cluster Features
  enable_network_policy                  = true
  enable_http_load_balancing            = true
  enable_horizontal_pod_autoscaling     = true
  enable_gce_persistent_disk_csi_driver = true
  enable_binary_authorization           = false # Enable if using Binary Authorization
  enable_shielded_nodes                 = true

  # Release Channel
  release_channel = "REGULAR" # RAPID, REGULAR, or STABLE

  # Logging and Monitoring
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # Maintenance Window
  maintenance_window = {
    start_time = "03:00" # 3 AM UTC
  }

  # Cluster Labels
  cluster_resource_labels = merge(
    var.labels,
    {
      cluster_name = var.gke_cluster_name
    }
  )

  # Deletion Protection
  deletion_protection = true

  # Timeouts
  cluster_timeout_create = "45m"
  cluster_timeout_update = "45m"
  cluster_timeout_delete = "45m"

  # Node Pools
  node_pools = [
    # Primary application node pool
    {
      name               = "app-pool-${var.environment}"
      initial_node_count = var.gke_node_pool_min_count
      machine_type       = var.gke_node_pool_machine_type
      disk_size_gb       = 100
      disk_type          = "pd-standard"
      image_type         = "COS_CONTAINERD"
      preemptible        = false
      spot               = false

      # Service Account
      service_account = module.iam.service_account_emails["gke-node-sa-${var.environment}"]

      # OAuth Scopes
      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]

      # Labels
      labels = merge(
        var.labels,
        {
          node_pool = "app-pool"
          workload  = "applications"
        }
      )

      # Metadata
      metadata = {
        disable-legacy-endpoints = "true"
      }

      # Tags
      tags = ["gke-node", "${var.environment}", "app-pool"]

      # Auto-repair and auto-upgrade
      auto_repair  = true
      auto_upgrade = true

      # Autoscaling
      autoscaling = {
        min_node_count  = var.gke_node_pool_min_count
        max_node_count  = var.gke_node_pool_max_count
        location_policy = "BALANCED"
      }

      # Upgrade Settings
      upgrade_settings = {
        max_surge       = 1
        max_unavailable = 0
        strategy        = "SURGE"
      }
    },
    # System/monitoring node pool (smaller nodes)
    {
      name               = "system-pool-${var.environment}"
      initial_node_count = 1
      machine_type       = "e2-medium"
      disk_size_gb       = 50
      disk_type          = "pd-standard"
      image_type         = "COS_CONTAINERD"
      preemptible        = false
      spot               = false

      service_account = module.iam.service_account_emails["gke-node-sa-${var.environment}"]

      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]

      labels = merge(
        var.labels,
        {
          node_pool = "system-pool"
          workload  = "system"
        }
      )

      metadata = {
        disable-legacy-endpoints = "true"
      }

      tags = ["gke-node", "${var.environment}", "system-pool"]

      auto_repair  = true
      auto_upgrade = true

      # Smaller autoscaling for system workloads
      autoscaling = {
        min_node_count  = 1
        max_node_count  = 3
        location_policy = "BALANCED"
      }

      # Taints to ensure only system workloads run here
      taints = [
        {
          key    = "workload-type"
          value  = "system"
          effect = "NO_SCHEDULE"
        }
      ]

      upgrade_settings = {
        max_surge       = 1
        max_unavailable = 0
        strategy        = "SURGE"
      }
    }
  ]

  # Workload Identity Service Accounts
  workload_identity_service_accounts = [
    {
      name                = "voting-app-sa-${var.environment}"
      namespace           = "default"
      k8s_service_account = "voting-app"
      description         = "Workload Identity for voting app"
      roles = [
        "roles/cloudsql.client",
        "roles/logging.logWriter",
      ]
    },
    {
      name                = "results-app-sa-${var.environment}"
      namespace           = "default"
      k8s_service_account = "results-app"
      description         = "Workload Identity for results app"
      roles = [
        "roles/cloudsql.client",
        "roles/logging.logWriter",
      ]
    },
    {
      name                = "worker-app-sa-${var.environment}"
      namespace           = "default"
      k8s_service_account = "worker-app"
      description         = "Workload Identity for worker app"
      roles = [
        "roles/cloudsql.client",
        "roles/logging.logWriter",
      ]
    }
  ]

  depends_on = [module.network, module.iam]
}
