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