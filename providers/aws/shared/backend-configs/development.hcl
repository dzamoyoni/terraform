# Development Environment Backend Configuration
# Optimized for development speed and cost efficiency

bucket         = "terraform-state-development-us-east-1"
region         = "us-east-1"
dynamodb_table = "terraform-locks-development"

# Development-specific settings
encrypt        = true
versioning    = true

# Shorter retention for development states
lifecycle_rule {
  id      = "development_state_cleanup"
  enabled = true

  # Keep current versions for 30 days
  expiration {
    days = 30
  }

  # Keep non-current versions for 7 days
  noncurrent_version_expiration {
    days = 7
  }

  # Transition to IA quickly to save costs
  noncurrent_version_transition {
    days          = 1
    storage_class = "STANDARD_IA"
  }
}

# Cost-optimized encryption for development
server_side_encryption_configuration {
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Tags for development environment
tags = {
  Environment         = "development"
  Purpose            = "terraform-state"
  ManagedBy          = "terraform"
  BusinessCriticality = "low"
  DataClassification = "internal"
  CostCenter         = "infrastructure-development"
  OwnerTeam          = "development-team"
  AutoCleanup        = "true"
}
