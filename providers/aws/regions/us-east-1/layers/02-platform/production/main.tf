terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration loaded from backend.hcl file
  # Use: terraform init -backend-config=backend.hcl
}

provider "aws" {
  region = "us-east-1"
}
