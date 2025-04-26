terraform {
  required_version = "~> 1.8.4"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.31.0"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

  }
}