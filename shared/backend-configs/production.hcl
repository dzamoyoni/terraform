# Production Environment Backend Configuration
# Uses the same S3 bucket as current environment but with new key structure

bucket         = "usest1-terraform-state-ezra"
region         = "us-east-1"
dynamodb_table = "terraform-locks"

# Production-specific settings
encrypt = true

# State isolation for new environment structure
key = "regions/us-east-1/environments/production/terraform.tfstate"
