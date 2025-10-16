# Backend configuration for us-east-2 shared-services layer
# Generated automatically by provision-s3-infrastructure.sh
bucket         = "ohio-01-terraform-state-production"
key            = "regions/us-east-2/layers/06-shared-services/production/terraform.tfstate"
region         = "us-east-2"
encrypt        = true
dynamodb_table = "terraform-locks-us-east"
