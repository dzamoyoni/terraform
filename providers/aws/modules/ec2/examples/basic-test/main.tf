# Basic test for EC2 module
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Test basic EC2 instance creation
module "test_instance" {
  source = "../../"
  
  name          = "test-ec2-instance"
  ami_id        = "ami-0779caf41f9ba54f0"  # Amazon Linux 2023
  instance_type = "t3.micro"
  key_name      = "terraform-key"
  subnet_id     = "subnet-0a6936df3ff9a4f77"  # Use existing subnet
  
  # Create default security group
  create_default_security_group = true
  
  # Test basic storage
  volume_size = 20
  volume_type = "gp3"
  
  # Test IAM role creation
  create_iam_role = true
  enable_ssm      = true
  
  # Test additional volume
  extra_volumes = [{
    device_name = "/dev/sdf"
    size        = 10
    type        = "gp3"
    encrypted   = true
    name        = "test-data-volume"
  }]
  
  # Test tagging
  environment  = "test"
  service_type = "test"
  client_name  = "test-client"
  
  tags = {
    Purpose = "module-testing"
    Owner   = "terraform"
  }
}

# Output key information
output "test_instance_id" {
  value = module.test_instance.instance_id
}

output "test_instance_private_ip" {
  value = module.test_instance.private_ip
}

output "test_iam_role" {
  value = module.test_instance.iam_role_name
}
