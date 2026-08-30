# Terraform Cloud Backend Configuration
terraform {
  required_version = ">= 1.0"

  # Terraform Cloud Backend
  cloud {
    organization = "YOUR_TFC_ORGANIZATION_NAME" # Replace with your Terraform Cloud organization name

    workspaces {
      name = "cloud-app-gcp-prd" # Production workspace name
    }
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# Google Provider Configuration
provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}
