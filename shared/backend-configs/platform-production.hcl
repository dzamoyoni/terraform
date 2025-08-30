bucket         = "usest1-terraform-state-ezra"
key            = "layers/platform/production/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-locks"
encrypt        = true

# Platform layer state management
# This contains the EKS cluster and shared platform services
# that depend on foundation layer through SSM parameters
