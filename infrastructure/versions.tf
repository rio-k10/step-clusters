terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  # Local state; you can add a backend block later if needed
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
  profile = var.aws_profile
}
