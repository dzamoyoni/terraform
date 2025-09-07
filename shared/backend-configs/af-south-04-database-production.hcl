# 🔒 Backend configuration for 04-Database Layer - AF-South-1 Production
# CRITICAL: This file configures access to protected Terraform state
# Uses postgres-ec2 module for high-availability PostgreSQL deployments

bucket         = "cptwn-terraform-state-ezra"
key            = "providers/aws/regions/af-south-1/layers/04-database-layer/production/terraform.tfstate"
region         = "af-south-1"
dynamodb_table = "terraform-locks-af-south"
encrypt        = true
