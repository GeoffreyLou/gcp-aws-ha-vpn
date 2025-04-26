terraform {
  required_version = "~> 1.10.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.17.0"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.96.0"
    }

  }
}

resource "google_project_service" "main" {
  for_each = toset([
    "compute.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com"
  ])
  project = var.gcp-project
  service = each.key
}