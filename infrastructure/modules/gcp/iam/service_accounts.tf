# Service Accounts Configuration

resource "google_service_account" "service_accounts" {
  for_each = { for sa in var.service_accounts : sa.account_id => sa }

  account_id   = each.value.account_id
  display_name = lookup(each.value, "display_name", each.value.account_id)
  description  = lookup(each.value, "description", "Service account managed by Terraform")
  project      = var.project_id
  disabled     = lookup(each.value, "disabled", false)
}

# Service Account Keys (optional)
resource "google_service_account_key" "service_account_keys" {
  for_each = {
    for sa in var.service_accounts :
    sa.account_id => sa
    if lookup(sa, "create_key", false)
  }

  service_account_id = google_service_account.service_accounts[each.key].name
  key_algorithm      = lookup(each.value, "key_algorithm", "KEY_ALG_RSA_2048")
  public_key_type    = lookup(each.value, "public_key_type", "TYPE_X509_PEM_FILE")
}
