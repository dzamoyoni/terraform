terraform {
  # Backend configuration loaded from backend.hcl file
  # Use: terraform init -backend-config=backend.hcl
provider "aws" {
  region = "us-east-1"
}
