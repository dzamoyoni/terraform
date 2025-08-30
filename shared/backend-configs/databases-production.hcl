bucket         = "usest1-terraform-state-ezra"
key            = "layers/databases/production/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-locks"
encrypt        = true

# Layer-specific state management
# This isolates database layer state from other infrastructure layers
# while maintaining connection through SSM parameters
