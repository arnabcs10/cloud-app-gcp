# Workload Identity Configuration

# Google Service Accounts for Workload Identity
resource "google_service_account" "workload_identity" {
  for_each = { for sa in var.workload_identity_service_accounts : sa.name => sa }

  account_id   = each.value.name
  display_name = lookup(each.value, "description", "Service account for ${each.value.k8s_service_account}")
  description  = lookup(each.value, "description", "Workload Identity service account for ${each.value.namespace}/${each.value.k8s_service_account}")
  project      = var.project_id
}

# Workload Identity binding between K8s SA and Google SA
resource "google_service_account_iam_member" "workload_identity_binding" {
  for_each = { for sa in var.workload_identity_service_accounts : sa.name => sa }

  service_account_id = google_service_account.workload_identity[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${each.value.namespace}/${each.value.k8s_service_account}]"

  depends_on = [google_service_account.workload_identity]
}

# Project-level IAM bindings for service accounts
resource "google_project_iam_member" "workload_identity_roles" {
  for_each = merge([
    for sa_key, sa in var.workload_identity_service_accounts : {
      for role in sa.roles : "${sa_key}-${role}" => {
        service_account = google_service_account.workload_identity[sa_key].email
        role            = role
      }
    }
  ]...)

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${each.value.service_account}"

  depends_on = [google_service_account.workload_identity]
}
