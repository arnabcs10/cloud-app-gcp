# IAM Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "service_accounts" {
  description = "List of service accounts to create"
  type = list(object({
    account_id   = string
    display_name = optional(string)
    description  = optional(string)
    disabled     = optional(bool)
    create_key   = optional(bool)
    key_algorithm = optional(string)
    public_key_type = optional(string)
    project_roles = optional(list(string))
    iam_bindings = optional(list(object({
      role   = string
      member = string
    })))
  }))
  default = []
}

variable "custom_iam_bindings" {
  description = "List of custom IAM bindings"
  type = list(object({
    member = string
    role   = string
    condition = optional(object({
      title       = string
      description = optional(string)
      expression  = string
    }))
  }))
  default = []
}

variable "create_gke_node_service_account" {
  description = "Create a service account for GKE nodes with standard permissions"
  type        = bool
  default     = false
}

variable "gke_node_service_account_key" {
  description = "The key (account_id) of the GKE node service account in the service_accounts list"
  type        = string
  default     = "gke-node-sa"
}
