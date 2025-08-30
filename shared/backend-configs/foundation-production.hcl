bucket         = "usest1-terraform-state-ezra"
key            = "layers/foundation/production/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-locks"
encrypt        = true

# Foundation layer state management
# This contains the core VPC, networking, and security group infrastructure
# that other layers depend on through SSM parameters
