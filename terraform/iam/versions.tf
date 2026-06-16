terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }

  # IAM is account-global and intentionally separate from the env infra so
  # `down.ps1` (which only destroys terraform/envs/dev) never deletes your
  # users, groups or roles. Local state by default; switch to S3 for teams.
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project
      Component = "iam-identity"
      ManagedBy = "terraform"
    }
  }
}
