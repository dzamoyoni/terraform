# 🗄️ Database Layer - AF-South-1 Production
# EC2-BASED DATABASE INSTANCES WITH CLIENT ISOLATION
# Provides dedicated database servers for CPTWN clients with proper isolation and connectivity
# Clients: MTN Ghana Prod, Orange Madagascar Prod

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration loaded from backend.hcl file
  # Use: terraform init -backend-config=backend.hcl
  backend "s3" {}
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project         = "CPTWN-Multi-Client-EKS"
      Environment     = var.environment
      ManagedBy       = "Terraform"
      CriticalInfra   = "true"
      BackupRequired  = "true"
      SecurityLevel   = "High"
      Region          = var.region
      Layer           = "Databases"
      DeploymentPhase = "Phase-3"
    }
  }
}

# 📊 DATA SOURCES - Foundation and Platform Layer Outputs
data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "providers/aws/regions/${var.region}/layers/01-foundation/${var.environment}/terraform.tfstate"
    region = var.terraform_state_region
  }
}

data "terraform_remote_state" "platform" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "providers/aws/regions/${var.region}/layers/02-platform/${var.environment}/terraform.tfstate"
    region = var.terraform_state_region
  }
}

# 📊 DATA SOURCES - AWS Account Info
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# 🔍 LOCALS - CPTWN Standards and AF-South-1 Configuration
locals {
  # CPTWN standard tags applied to all resources
  cptwn_tags = {
    Project         = "CPTWN-Multi-Client-EKS"
    Environment     = var.environment
    ManagedBy       = "Terraform"
    CriticalInfra   = "true"
    BackupRequired  = "true"
    SecurityLevel   = "High"
    Region          = var.region
    Layer           = "Databases"
    DeploymentPhase = "Phase-3"
    Company         = "CPTWN"
    Architecture    = "Multi-Client"
  }

  # Foundation and Platform layer data
  vpc_id             = data.terraform_remote_state.foundation.outputs.vpc_id
  availability_zones = data.terraform_remote_state.foundation.outputs.availability_zones
  cluster_name       = data.terraform_remote_state.platform.outputs.cluster_name

  # 🎯 STRATEGY: Place databases in dedicated database subnets for security isolation
  # but match EKS nodegroup labels for proper connectivity and management

  # MTN Ghana Prod Configuration - Use dedicated database subnets
  mtn_ghana_database_subnet_id      = data.terraform_remote_state.foundation.outputs.mtn_ghana_prod_database_subnet_ids[0] # af-south-1a
  mtn_ghana_database_security_group = data.terraform_remote_state.foundation.outputs.mtn_ghana_prod_security_groups.database
  mtn_ghana_eks_security_group      = data.terraform_remote_state.foundation.outputs.mtn_ghana_prod_security_groups.eks

  # Orange Madagascar Prod Configuration - Use dedicated database subnets
  orange_madagascar_database_subnet_id      = data.terraform_remote_state.foundation.outputs.orange_madagascar_prod_database_subnet_ids[0] # af-south-1a
  orange_madagascar_database_security_group = data.terraform_remote_state.foundation.outputs.orange_madagascar_prod_security_groups.database
  orange_madagascar_eks_security_group      = data.terraform_remote_state.foundation.outputs.orange_madagascar_prod_security_groups.eks

  # KMS Key for AF-South-1 (we'll use AWS managed key for now)
  kms_key_id = "arn:aws:kms:af-south-1:101886104835:alias/aws/ebs"
}

# 🔍 AMI Data Source for Latest Debian 12 (Bookworm)
data "aws_ami" "debian" {
  most_recent = true
  owners      = ["136693071363"] # Debian Official

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# 📱 MTN GHANA PROD DATABASE INSTANCE
resource "aws_instance" "mtn_ghana_db_prod" {
  ami                    = data.aws_ami.debian.id
  instance_type          = var.mtn_ghana_config.instance_type
  key_name               = var.key_name
  subnet_id              = local.mtn_ghana_database_subnet_id        # Dedicated database subnet for isolation
  vpc_security_group_ids = [local.mtn_ghana_database_security_group] # Database security group allows EKS access
  availability_zone      = local.availability_zones[0]               # af-south-1a

  disable_api_termination = true
  monitoring              = var.enable_monitoring
  ebs_optimized           = true

  iam_instance_profile = aws_iam_instance_profile.mtn_ghana_profile.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    iops                  = 3000
    throughput            = 125
    encrypted             = var.enable_encryption
    kms_key_id            = var.enable_encryption ? local.kms_key_id : null
    delete_on_termination = true

    tags = merge(local.cptwn_tags, {
      Name              = "mtn-ghana-prod-database-root-volume"
      Client            = "mtn-ghana-prod"
      Purpose           = "database"
      Service           = "database"
      VolumeType        = "root"
      CriticalityLevel  = "critical"
      MonitoringEnabled = "true"
      Cluster           = local.cluster_name
      # 🎯 EKS Integration Labels (match nodegroup labels for connectivity)
      NodeGroup = "database"
    })
  }

  tags = merge(local.cptwn_tags, {
    Name              = "mtn-ghana-prod-database"
    Client            = "mtn-ghana-prod"
    Purpose           = "database"
    Service           = "database"
    Project           = "mtn-ghana-prod"
    Owner             = "mtn-ghana-database-team"
    BusinessUnit      = "telecommunications"
    CostCenter        = "mtn-ghana-production"
    DataClass         = "restricted"
    CriticalityLevel  = "critical"
    BackupSchedule    = var.mtn_ghana_config.backup_schedule
    MaintenanceWindow = var.mtn_ghana_config.maintenance_window
    MonitoringEnabled = "true"
    Cluster           = local.cluster_name

    # 🎯 EKS Integration Labels (match nodegroup labels for connectivity)
    NodeGroup = "database"

    # 🔗 Client-specific connectivity labels  
    ClientNetworkTier  = "database"
    ClientEKSConnected = "true"
    EKSSecurityGroup   = local.mtn_ghana_eks_security_group
  })

  lifecycle {
    prevent_destroy = true
  }
}

# 💾 MTN GHANA EXTRA EBS VOLUME
resource "aws_ebs_volume" "mtn_ghana_extra_prod" {
  availability_zone = local.availability_zones[0] # af-south-1a
  size              = var.mtn_ghana_config.volume_size
  type              = var.mtn_ghana_config.volume_type
  iops              = var.mtn_ghana_config.volume_iops
  encrypted         = var.enable_encryption
  kms_key_id        = var.enable_encryption ? local.kms_key_id : null

  tags = merge(local.cptwn_tags, {
    Name              = "mtn-ghana-prod-database-data-volume"
    Client            = "mtn-ghana-prod"
    Purpose           = "database"
    Service           = "database"
    VolumeType        = "data"
    Critical          = "true"
    CriticalityLevel  = "critical"
    MonitoringEnabled = "true"
    Cluster           = local.cluster_name
    NodeGroup         = "database"
  })

  lifecycle {
    prevent_destroy = true
  }
}

# 🔗 MTN GHANA VOLUME ATTACHMENT
resource "aws_volume_attachment" "mtn_ghana_extra_prod" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.mtn_ghana_extra_prod.id
  instance_id = aws_instance.mtn_ghana_db_prod.id

  lifecycle {
    prevent_destroy = true
  }
}

# 💾 MTN GHANA SECOND EXTRA EBS VOLUME (for logs/backup) - COMMENTED OUT FOR INITIAL DEPLOYMENT
# resource "aws_ebs_volume" "mtn_ghana_extra2_prod" {
#   availability_zone = local.availability_zones[0]  # af-south-1a
#   size             = 20  # Smaller size for logs/backup
#   type             = "gp3"  # Standard performance for logs
#   iops             = 3000
#   throughput       = 125
#   encrypted        = var.enable_encryption
#   kms_key_id       = var.enable_encryption ? local.kms_key_id : null

#   tags = merge(local.cptwn_tags, {
#     Name              = "mtn-ghana-prod-database-logs-volume"
#     Client            = "mtn-ghana-prod"
#     Purpose           = "database"
#     Service           = "database"
#     VolumeType        = "logs"
#     Critical          = "true"
#     CriticalityLevel  = "high"
#     MonitoringEnabled = "true"
#     Cluster           = local.cluster_name
#     NodeGroup         = "database"
#   })

#   lifecycle {
#     prevent_destroy = true
#   }
# }

# # 🔗 MTN GHANA SECOND VOLUME ATTACHMENT - COMMENTED OUT FOR INITIAL DEPLOYMENT
# resource "aws_volume_attachment" "mtn_ghana_extra2_prod" {
#   device_name = "/dev/sdg"
#   volume_id   = aws_ebs_volume.mtn_ghana_extra2_prod.id
#   instance_id = aws_instance.mtn_ghana_db_prod.id

#   lifecycle {
#     prevent_destroy = true
#   }
# }

# 🍊 ORANGE MADAGASCAR PROD DATABASE INSTANCE
# resource "aws_instance" "orange_madagascar_db" {
#   ami                     = data.aws_ami.debian.id
#   instance_type           = var.orange_madagascar_config.instance_type
#   key_name                = var.key_name
#   subnet_id               = local.orange_madagascar_database_subnet_id  # Dedicated database subnet for isolation
#   vpc_security_group_ids  = [local.orange_madagascar_database_security_group]  # Database security group allows EKS access
#   availability_zone       = local.availability_zones[0]  # af-south-1a

#   disable_api_termination = true
#   monitoring              = var.enable_monitoring
#   ebs_optimized          = true

#   iam_instance_profile = aws_iam_instance_profile.orange_madagascar_profile.name

#   root_block_device {
#     volume_type           = "gp3"
#     volume_size           = 30
#     iops                  = 3000
#     throughput           = 125
#     encrypted            = var.enable_encryption
#     kms_key_id           = var.enable_encryption ? local.kms_key_id : null
#     delete_on_termination = true

#     tags = merge(local.cptwn_tags, {
#       Name              = "orange-madagascar-prod-database-root-volume"
#       Client            = "orange-madagascar-prod"
#       Purpose           = "database"
#       Service           = "database"
#       VolumeType        = "root"
#       CriticalityLevel  = "critical"
#       MonitoringEnabled = "true"
#       Cluster           = local.cluster_name
#       # 🎯 EKS Integration Labels (match nodegroup labels for connectivity)
#       NodeGroup         = "database"
#     })
#   }

#   tags = merge(local.cptwn_tags, {
#     Name                = "orange-madagascar-prod-database"
#     Client              = "orange-madagascar-prod"
#     Purpose             = "database"
#     Service             = "database"
#     Project             = "orange-madagascar-prod"
#     Owner               = "orange-madagascar-database-team"
#     BusinessUnit        = "telecommunications"
#     CostCenter          = "orange-madagascar-production"
#     DataClass           = "restricted"
#     CriticalityLevel    = "critical"
#     BackupSchedule      = var.orange_madagascar_config.backup_schedule
#     MaintenanceWindow   = var.orange_madagascar_config.maintenance_window
#     MonitoringEnabled   = "true"
#     Cluster             = local.cluster_name

#     # 🎯 EKS Integration Labels (match nodegroup labels for connectivity)
#     NodeGroup           = "database"

#     # 🔗 Client-specific connectivity labels
#     ClientNetworkTier   = "database"
#     ClientEKSConnected  = "true"
#     EKSSecurityGroup    = local.orange_madagascar_eks_security_group
#   })

#   lifecycle {
#     prevent_destroy = true
#   }
# }

# # 💾 ORANGE MADAGASCAR EXTRA EBS VOLUME
# resource "aws_ebs_volume" "orange_madagascar_extra" {
#   availability_zone = local.availability_zones[0]  # af-south-1a
#   size             = var.orange_madagascar_config.volume_size
#   type             = var.orange_madagascar_config.volume_type
#   iops             = var.orange_madagascar_config.volume_iops
#   encrypted        = var.enable_encryption
#   kms_key_id       = var.enable_encryption ? local.kms_key_id : null

#   tags = merge(local.cptwn_tags, {
#     Name              = "orange-madagascar-prod-database-data-volume"
#     Client            = "orange-madagascar-prod"
#     Purpose           = "database"
#     Service           = "database"
#     VolumeType        = "data"
#     Critical          = "true"
#     CriticalityLevel  = "critical"
#     MonitoringEnabled = "true"
#     Cluster           = local.cluster_name
#     NodeGroup         = "database"
#   })

#   lifecycle {
#     prevent_destroy = true
#   }
# }

# # 🔗 ORANGE MADAGASCAR VOLUME ATTACHMENT
# resource "aws_volume_attachment" "orange_madagascar_extra" {
#   device_name = "/dev/sdg"
#   volume_id   = aws_ebs_volume.orange_madagascar_extra.id
#   instance_id = aws_instance.orange_madagascar_db.id

#   lifecycle {
#     prevent_destroy = true
#   }
# }

# 🔐 MTN GHANA IAM ROLE FOR SSM
resource "aws_iam_role" "mtn_ghana_role" {
  name = "${local.cluster_name}-mtn-ghana-database-role"

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

  tags = merge(local.cptwn_tags, {
    Name    = "${local.cluster_name}-mtn-ghana-database-role"
    Client  = "mtn-ghana-prod"
    Purpose = "database-ssm-access"
  })
}

# 📋 MTN GHANA IAM POLICY ATTACHMENTS
resource "aws_iam_role_policy_attachment" "mtn_ghana_ssm_policy" {
  role       = aws_iam_role.mtn_ghana_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "mtn_ghana_cloudwatch_policy" {
  role       = aws_iam_role.mtn_ghana_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# 👤 MTN GHANA IAM INSTANCE PROFILE
resource "aws_iam_instance_profile" "mtn_ghana_profile" {
  name = "${local.cluster_name}-mtn-ghana-database-profile"
  role = aws_iam_role.mtn_ghana_role.name

  tags = merge(local.cptwn_tags, {
    Name    = "${local.cluster_name}-mtn-ghana-database-profile"
    Client  = "mtn-ghana-prod"
    Purpose = "database-ssm-access"
  })
}

# # 🔐 ORANGE MADAGASCAR IAM ROLE FOR SSM
# resource "aws_iam_role" "orange_madagascar_role" {
#   name = "${local.cluster_name}-orange-madagascar-database-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "ec2.amazonaws.com"
#         }
#       }
#     ]
#   })

#   tags = merge(local.cptwn_tags, {
#     Name    = "${local.cluster_name}-orange-madagascar-database-role"
#     Client  = "orange-madagascar-prod"
#     Purpose = "database-ssm-access"
#   })
# }

# # 📋 ORANGE MADAGASCAR IAM POLICY ATTACHMENTS
# resource "aws_iam_role_policy_attachment" "orange_madagascar_ssm_policy" {
#   role       = aws_iam_role.orange_madagascar_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# }

# resource "aws_iam_role_policy_attachment" "orange_madagascar_cloudwatch_policy" {
#   role       = aws_iam_role.orange_madagascar_role.name
#   policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
# }

# # 👤 ORANGE MADAGASCAR IAM INSTANCE PROFILE
# resource "aws_iam_instance_profile" "orange_madagascar_profile" {
#   name = "${local.cluster_name}-orange-madagascar-database-profile"
#   role = aws_iam_role.orange_madagascar_role.name

#   tags = merge(local.cptwn_tags, {
#     Name    = "${local.cluster_name}-orange-madagascar-database-profile"
#     Client  = "orange-madagascar-prod"
#     Purpose = "database-ssm-access"
#   })
# }
