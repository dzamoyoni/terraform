bucket         = "usest1-terraform-state-ezra"
key            = "layers/client/production/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-locks"
encrypt        = true

# Client layer state management
# This contains the EKS nodegroups and cluster autoscaler
# that depend on platform layer through SSM parameters
