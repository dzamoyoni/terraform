bucket         = "usest1-terraform-state-ezra"
key            = "providers/aws/regions/us-east-1/layers/01-foundation/production/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "terraform-locks-us-east-1"
