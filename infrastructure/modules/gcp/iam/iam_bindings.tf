# IAM Bindings Configuration

# Project-level IAM bindings
resource "google_project_iam_member" "project_bindings" {
  for_each = merge([
    for sa_key, sa in var.service_accounts : {
      for role in lookup(sa, "project_roles", []) :
      "${sa_key}-${role}" => {
        service_account = google_service_account.service_accounts[sa_key].email
        role            = role
      }
    }
  ]...)

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${each.value.service_account}"

  depends_on = [google_service_account.service_accounts]
}

# Custom IAM bindings (for more granular control)
resource "google_project_iam_member" "custom_bindings" {
  for_each = { for binding in var.custom_iam_bindings : "${binding.member}-${binding.role}" => binding }

  project = var.project_id
  role    = each.value.role
  member  = each.value.member

  dynamic "condition" {
    for_each = lookup(each.value, "condition", null) != null ? [each.value.condition] : []
    content {
      title       = condition.value.title
      description = lookup(condition.value, "description", null)
      expression  = condition.value.expression
    }
  }
}

# Service Account IAM bindings (for impersonation)
resource "google_service_account_iam_member" "service_account_bindings" {
  for_each = merge([
    for sa_key, sa in var.service_accounts : {
      for binding in lookup(sa, "iam_bindings", []) :
      "${sa_key}-${binding.role}-${binding.member}" => {
        service_account = google_service_account.service_accounts[sa_key].email
        role            = binding.role
        member          = binding.member
      }
    }
  ]...)

  service_account_id = "projects/${var.project_id}/serviceAccounts/${each.value.service_account}"
  role               = each.value.role
  member             = each.value.member

  depends_on = [google_service_account.service_accounts]
}

# Predefined role bindings for common patterns
resource "google_project_iam_member" "gke_node_service_account" {
  for_each = var.create_gke_node_service_account ? toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/artifactregistry.reader"
  ]) : toset([])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.service_accounts[var.gke_node_service_account_key].email}"

  depends_on = [google_service_account.service_accounts]
}
