# IAM Module Outputs

output "service_accounts" {
  description = "Map of service account details"
  value = {
    for k, v in google_service_account.service_accounts : k => {
      id          = v.id
      email       = v.email
      name        = v.name
      account_id  = v.account_id
      unique_id   = v.unique_id
      member      = "serviceAccount:${v.email}"
    }
  }
}

output "service_account_emails" {
  description = "Map of service account IDs to emails"
  value       = { for k, v in google_service_account.service_accounts : k => v.email }
}

output "service_account_ids" {
  description = "Map of service account IDs to resource IDs"
  value       = { for k, v in google_service_account.service_accounts : k => v.id }
}

output "service_account_keys" {
  description = "Map of service account keys (private keys)"
  value       = { for k, v in google_service_account_key.service_account_keys : k => v.private_key }
  sensitive   = true
}

output "service_account_public_keys" {
  description = "Map of service account public keys"
  value       = { for k, v in google_service_account_key.service_account_keys : k => v.public_key }
}

output "gke_node_service_account_email" {
  description = "Email of the GKE node service account (if created)"
  value       = var.create_gke_node_service_account ? google_service_account.service_accounts[var.gke_node_service_account_key].email : null
}

output "project_iam_bindings" {
  description = "List of project-level IAM bindings created"
  value = {
    for k, v in google_project_iam_member.project_bindings : k => {
      role   = v.role
      member = v.member
    }
  }
}

output "custom_iam_bindings" {
  description = "List of custom IAM bindings created"
  value = {
    for k, v in google_project_iam_member.custom_bindings : k => {
      role   = v.role
      member = v.member
    }
  }
}
