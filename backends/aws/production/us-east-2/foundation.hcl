# Backend configuration for us-east-2 foundation layer
# Generated automatically by provision-s3-infrastructure.sh
bucket         = "ohio-01-terraform-state-production"
key            = "providers/aws/regions/us-east-2/layers/01-foundation/production/terraform.tfstate"
region         = "us-east-2"
encrypt        = true
dynamodb_table = "terraform-locks-us-east"
