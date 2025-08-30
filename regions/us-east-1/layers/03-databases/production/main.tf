terraform {
  required_version = ">= 1.0"
  
  backend "s3" {
    # Backend configuration will be provided via backend-config file
    # This enables proper state isolation for the database layer
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data sources for foundation layer outputs
data "aws_ssm_parameter" "vpc_id" {
  name = "/terraform/production/foundation/vpc_id"
}

data "aws_ssm_parameter" "private_subnets" {
  name = "/terraform/production/foundation/private_subnets"
}

data "aws_ssm_parameter" "database_security_group_id" {
  name = "/terraform/production/foundation/database_security_group_id"
}

data "aws_kms_key" "ebs" {
  key_id = "alias/aws/ebs"
}

# Local values
locals {
  common_tags = {
    ManagedBy   = "terraform"
    Environment = var.environment
    Layer       = "databases"
    Region      = var.region
  }

  # Parse security group IDs - using exact security groups from existing instances
  security_group_ids = [
    "sg-067bc5c25980da2cc",
    "sg-0fc956334f67b2f64"
  ]

  # Subnet mappings based on extracted configurations
  mtn_ghana_subnet_id = "subnet-0ec8a91aa274caea1"  # us-east-1b
  ezra_subnet_id      = "subnet-0a6936df3ff9a4f77"  # us-east-1a
}

# MTN Ghana Database Instance
resource "aws_instance" "mtn_ghana_db" {
  ami                     = "ami-0779caf41f9ba54f0"
  instance_type           = "r5.large"
  key_name                = "terraform-key"
  subnet_id               = local.mtn_ghana_subnet_id
  vpc_security_group_ids  = local.security_group_ids
  availability_zone       = "us-east-1b"
  
  disable_api_termination = true
  monitoring              = false
  ebs_optimized          = false
  
  iam_instance_profile = aws_iam_instance_profile.mtn_ghana_profile.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    iops                  = 3000
    throughput           = 125
    encrypted            = false
    delete_on_termination = true
    
    tags = merge(local.common_tags, {
      Name              = "mtn-ghana-prod-database-root-volume"
      Client            = "mtn-ghana"
      Purpose           = "database"
      Service           = "database"
      VolumeType        = "root"
      BackupRequired    = "true"
      CriticalityLevel  = "critical"
      MonitoringEnabled = "true"
      Cluster           = "us-test-cluster-01"
    })
  }

  tags = merge(local.common_tags, {
    Name                = "mtn-ghana-prod-database"
    Client              = "mtn-ghana"
    Purpose             = "database"
    Service             = "database"
    Project             = "mtn-ghana-prod"
    Owner               = "mtn-ghana-database-team"
    BusinessUnit        = "telecommunications"
    CostCenter          = "mtn-ghana-production"
    DataClass           = "restricted"
    CriticalityLevel    = "critical"
    BackupRequired      = "true"
    BackupSchedule      = "continuous"
    MaintenanceWindow   = "sun:01:00-sun:02:00"
    MonitoringEnabled   = "true"
    Cluster             = "us-test-cluster-01"
  })
  
  lifecycle {
    prevent_destroy = true
  }
}

# MTN Ghana Extra EBS Volume
resource "aws_ebs_volume" "mtn_ghana_extra" {
  availability_zone = "us-east-1b"
  size             = 50
  type             = "io2"
  iops             = 10000
  encrypted        = true
  kms_key_id       = "arn:aws:kms:us-east-1:101886104835:key/882843c1-8ad3-460d-90a0-3cb174c55207"

  tags = merge(local.common_tags, {
    Name              = "mtn-ghana-prod-database-extra-volume-1"
    Client            = "mtn-ghana"
    Purpose           = "database"
    Service           = "database"
    VolumeType        = "data"
    Critical          = "true"
    BackupRequired    = "true"
    CriticalityLevel  = "critical"
    MonitoringEnabled = "true"
    Cluster           = "us-test-cluster-01"
  })
  
  lifecycle {
    prevent_destroy = true
  }
}

# MTN Ghana Volume Attachment
resource "aws_volume_attachment" "mtn_ghana_extra" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.mtn_ghana_extra.id
  instance_id = aws_instance.mtn_ghana_db.id
  
  lifecycle {
    prevent_destroy = true
  }
}

# Ezra Database Instance
resource "aws_instance" "ezra_db" {
  ami                     = "ami-0779caf41f9ba54f0"
  instance_type           = "r5.large"
  key_name                = "terraform-key"
  subnet_id               = local.ezra_subnet_id
  vpc_security_group_ids  = local.security_group_ids
  availability_zone       = "us-east-1a"
  
  disable_api_termination = true
  monitoring              = true
  ebs_optimized          = false
  
  iam_instance_profile = aws_iam_instance_profile.ezra_profile.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    iops                  = 3000
    throughput           = 125
    encrypted            = true
    kms_key_id           = "arn:aws:kms:us-east-1:101886104835:key/882843c1-8ad3-460d-90a0-3cb174c55207"
    delete_on_termination = true
    
    tags = merge(local.common_tags, {
      Name              = "ezra-prod-app-01-root-volume"
      Client            = "ezra"
      Purpose           = "database"
      Service           = "database"
      VolumeType        = "root"
      BackupRequired    = "true"
      CriticalityLevel  = "critical"
      MonitoringEnabled = "true"
      Cluster           = "us-test-cluster-01"
    })
  }

  tags = merge(local.common_tags, {
    Name                = "ezra-prod-app-01"
    Client              = "ezra"
    Purpose             = "database"
    Service             = "database"
    Project             = "ezra-prod"
    Owner               = "ezra-team"
    BusinessUnit        = "fintech"
    CostCenter          = "ezra-production"
    DataClass           = "restricted"
    CriticalityLevel    = "critical"
    BackupRequired      = "true"
    BackupSchedule      = "hourly"
    MaintenanceWindow   = "sun:04:00-sun:05:00"
    MonitoringEnabled   = "true"
    Cluster             = "us-test-cluster-01"
  })
  
  lifecycle {
    prevent_destroy = true
  }
}

# Ezra Extra EBS Volume
resource "aws_ebs_volume" "ezra_extra" {
  availability_zone = "us-east-1a"
  size             = 20
  type             = "gp3"
  iops             = 3000
  encrypted        = true
  kms_key_id       = "arn:aws:kms:us-east-1:101886104835:key/882843c1-8ad3-460d-90a0-3cb174c55207"

  tags = merge(local.common_tags, {
    Name              = "ezra-prod-app-01-extra-volume-1"
    Client            = "ezra"
    Purpose           = "database"
    Service           = "database"
    VolumeType        = "data"
    Critical          = "true"
    BackupRequired    = "true"
    CriticalityLevel  = "critical"
    MonitoringEnabled = "true"
    Cluster           = "us-test-cluster-01"
  })
  
  lifecycle {
    prevent_destroy = true
  }
}

# Ezra Volume Attachment
resource "aws_volume_attachment" "ezra_extra" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.ezra_extra.id
  instance_id = aws_instance.ezra_db.id
  
  lifecycle {
    prevent_destroy = true
  }
}

# MTN Ghana IAM Role for SSM
resource "aws_iam_role" "mtn_ghana_role" {
  name = "mtn-ghana-prod-database-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "mtn-ghana-prod-database-ssm-role"
    Client  = "mtn-ghana"
    Purpose = "database-ssm-access"
  })
}

# MTN Ghana IAM Policy Attachment
resource "aws_iam_role_policy_attachment" "mtn_ghana_ssm_policy" {
  role       = aws_iam_role.mtn_ghana_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# MTN Ghana IAM Instance Profile
resource "aws_iam_instance_profile" "mtn_ghana_profile" {
  name = "mtn-ghana-prod-database-ssm-profile"
  role = aws_iam_role.mtn_ghana_role.name

  tags = merge(local.common_tags, {
    Name    = "mtn-ghana-prod-database-ssm-profile"
    Client  = "mtn-ghana"
    Purpose = "database-ssm-access"
  })
}

# Ezra IAM Role for SSM
resource "aws_iam_role" "ezra_role" {
  name = "ezra-prod-app-01-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "ezra-prod-app-01-ssm-role"
    Client  = "ezra"
    Purpose = "database-ssm-access"
  })
}

# Ezra IAM Policy Attachment
resource "aws_iam_role_policy_attachment" "ezra_ssm_policy" {
  role       = aws_iam_role.ezra_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Ezra IAM Instance Profile
resource "aws_iam_instance_profile" "ezra_profile" {
  name = "ezra-prod-app-01-ssm-profile"
  role = aws_iam_role.ezra_role.name

  tags = merge(local.common_tags, {
    Name    = "ezra-prod-app-01-ssm-profile"
    Client  = "ezra"
    Purpose = "database-ssm-access"
  })
}
