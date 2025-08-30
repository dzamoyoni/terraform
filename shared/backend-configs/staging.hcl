# Staging Environment Backend Configuration
# Isolated state management for staging workloads

bucket         = "terraform-state-staging-multiregion"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock-staging"

# Staging-specific settings
encrypt        = true
versioning    = true

# State isolation by environment and region
key = "environments/staging/{region}/{cluster}/terraform.tfstate"

# Standard encryption for staging
server_side_encryption_configuration {
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Tags for cost allocation
tags = {
  Environment = "staging"
  Purpose     = "terraform-state"
  Criticality = "medium"
  ManagedBy   = "devops-team"
}
