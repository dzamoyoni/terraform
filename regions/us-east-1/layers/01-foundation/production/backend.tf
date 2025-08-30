# ============================================================================
# Foundation Layer Backend Configuration
# ============================================================================
# This file contains the backend configuration for the foundation layer.
# It uses the existing backend configuration pattern and points to the
# foundation-production.hcl file for backend settings.
# ============================================================================

# The backend block in main.tf references this via -backend-config
# terraform init -backend-config=../../../../../shared/backend-configs/foundation-production.hcl

# Backend configuration is loaded from:
# /shared/backend-configs/foundation-production.hcl
# 
# Contents:
# bucket         = "usest1-terraform-state-ezra"
# key            = "layers/foundation/production/terraform.tfstate"
# region         = "us-east-1"
# dynamodb_table = "terraform-locks"
# encrypt        = true
