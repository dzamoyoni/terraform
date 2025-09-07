# 🔒 Backend configuration for Shared Services Layer - AF-South-1 Production
# CRITICAL: This file configures access to protected Terraform state

bucket         = "cptwn-terraform-state-ezra"
key            = "layers/shared-services/af-south-1/production/terraform.tfstate"
region         = "af-south-1"
dynamodb_table = "terraform-locks-af-south"
encrypt        = true
