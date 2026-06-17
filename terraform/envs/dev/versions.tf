terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  # POC default: local state (clean, complete one-click teardown).
  # For team/production use, create the backend with ../../bootstrap and
  # uncomment the block below (values are printed by the bootstrap output).
  #
  # backend "s3" {
  #   bucket         = "projectx-tfstate-<account-id>"
  #   key            = "envs/dev/terraform.tfstate"
  #   region         = "ap-south-1"
  #   dynamodb_table = "projectx-tflock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
