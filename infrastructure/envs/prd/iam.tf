# IAM Module - Production Environment

module "iam" {
  source = "../../modules/gcp/iam"

  project_id = var.project_id

  # Service Accounts
  service_accounts = [
    # GKE Node Pool Service Account
    {
      account_id   = "gke-node-sa-${var.environment}"
      display_name = "GKE Node Pool Service Account - Production"
      description  = "Service account for GKE node pools in production environment"
      disabled     = false
      create_key   = false # Use Workload Identity instead of keys
      project_roles = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter",
        "roles/monitoring.viewer",
      ]
    },

    # Artifact Registry Service Account
    {
      account_id   = "artifact-registry-sa-${var.environment}"
      display_name = "Artifact Registry Service Account - Production"
      description  = "Service account for pulling images from Artifact Registry"
      disabled     = false
      create_key   = false
      project_roles = [
        "roles/artifactregistry.reader",
      ]
    }
  ]

  # Custom IAM Bindings
  custom_iam_bindings = [
    # Example: Grant specific users/groups viewer access
    # {
    #   member = "group:developers@example.com"
    #   role   = "roles/viewer"
    # },
    # {
    #   member = "user:admin@example.com"
    #   role   = "roles/owner"
    # }
  ]

  # Enable GKE node service account with standard roles
  create_gke_node_service_account = true
  gke_node_service_account_key    = "gke-node-sa-${var.environment}"
}