# ============================================================================
# PostgreSQL on EC2 Module - High Availability with Master-Replica Setup
# ============================================================================
# This module provides PostgreSQL databases running on EC2 instances with:
# - Master-Replica replication for high availability
# - Client-specific isolation and security
# - Automated backup and monitoring
# - EBS encryption and optimization
# - Security group and IAM configuration
# - Client tagging and resource naming
# ============================================================================

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Local variables for consistent naming and configuration
locals {
  # Instance naming
  master_name  = "${var.client_name}-${var.environment}-db-master"
  replica_name = "${var.client_name}-${var.environment}-db-replica"
  
  # Common tags for all resources
  common_tags = merge(var.tags, {
    Client      = var.client_name
    Environment = var.environment
    Service     = "database"
    Engine      = "postgresql"
    ManagedBy   = "terraform"
    Layer       = "database"
  })
  
  # Security group rules for PostgreSQL
  postgres_port = var.postgres_port
  
  # User data for PostgreSQL setup
  master_user_data = base64encode(templatefile("${path.module}/user-data/master-setup.sh", {
    postgres_version     = var.postgres_version
    postgres_port       = var.postgres_port
    replica_user        = var.replication_user
    replica_password    = var.replication_password
    db_name            = var.database_name
    db_user            = var.database_user
    db_password        = var.database_password
    backup_retention   = var.backup_retention_days
    monitoring_enabled = var.enable_monitoring
    client_name        = var.client_name
  }))
  
  replica_user_data = base64encode(templatefile("${path.module}/user-data/replica-setup.sh", {
    postgres_version     = var.postgres_version
    postgres_port       = var.postgres_port
    replica_user        = var.replication_user
    replica_password    = var.replication_password
    master_ip           = module.master_instance.private_ip
    monitoring_enabled = var.enable_monitoring
    client_name        = var.client_name
  }))
}

# ===================================================================================
# SECURITY GROUPS
# ===================================================================================

resource "aws_security_group" "postgres" {
  name_prefix = "${var.client_name}-${var.environment}-postgres-"
  description = "Security group for ${var.client_name} PostgreSQL database"
  vpc_id      = var.vpc_id

  # PostgreSQL port access from application subnets
  ingress {
    from_port   = local.postgres_port
    to_port     = local.postgres_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "PostgreSQL access from applications"
  }

  # Replication between master and replica
  ingress {
    from_port = local.postgres_port
    to_port   = local.postgres_port
    protocol  = "tcp"
    self      = true
    description = "PostgreSQL replication between instances"
  }

  # SSH access for management
  dynamic "ingress" {
    for_each = var.enable_ssh_access ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.management_cidr_blocks
      description = "SSH access for management"
    }
  }

  # Monitoring port access
  dynamic "ingress" {
    for_each = var.enable_monitoring ? [1] : []
    content {
      from_port   = 9187
      to_port     = 9187
      protocol    = "tcp"
      cidr_blocks = var.monitoring_cidr_blocks
      description = "PostgreSQL Exporter for monitoring"
    }
  }

  # Outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = "${var.client_name}-${var.environment}-postgres-sg"
    Type = "security-group"
  })
  
  lifecycle {
    create_before_destroy = true
  }
}

# ===================================================================================
# MASTER DATABASE INSTANCE
# ===================================================================================

module "master_instance" {
  source = "../ec2"

  # Instance configuration
  name                = local.master_name
  ami_id              = var.ami_id
  instance_type       = var.master_instance_type
  key_name            = var.key_name
  subnet_id           = var.master_subnet_id
  security_groups     = [aws_security_group.postgres.id]
  associate_public_ip = false

  # Advanced configuration
  enable_monitoring          = var.enable_monitoring
  ebs_optimized             = true
  disable_api_termination   = var.enable_deletion_protection
  user_data_base64          = local.master_user_data

  # Storage configuration
  volume_type                = var.root_volume_type
  volume_size               = var.root_volume_size
  volume_iops               = var.root_volume_iops
  volume_throughput         = var.root_volume_throughput
  root_volume_encrypted     = var.enable_encryption
  delete_root_on_termination = false
  kms_key_id               = var.kms_key_id

  # Additional EBS volumes for PostgreSQL data
  extra_volumes = [
    {
      device_name = "/dev/sdf"
      name        = "data-volume"
      size        = var.data_volume_size
      type        = var.data_volume_type
      iops        = var.data_volume_iops
      throughput  = var.data_volume_throughput
      encrypted   = var.enable_encryption
      kms_key_id  = var.kms_key_id
      tags = {
        Name        = "${local.master_name}-data-volume"
        VolumeType  = "database-data"
        Purpose     = "postgresql-data"
      }
    },
    {
      device_name = "/dev/sdg"
      name        = "wal-volume"
      size        = var.wal_volume_size
      type        = var.wal_volume_type
      iops        = var.wal_volume_iops
      throughput  = var.wal_volume_throughput
      encrypted   = var.enable_encryption
      kms_key_id  = var.kms_key_id
      tags = {
        Name        = "${local.master_name}-wal-volume"
        VolumeType  = "database-wal"
        Purpose     = "postgresql-wal"
      }
    },
    {
      device_name = "/dev/sdh"
      name        = "backup-volume"
      size        = var.backup_volume_size
      type        = "gp3"
      encrypted   = var.enable_encryption
      kms_key_id  = var.kms_key_id
      tags = {
        Name        = "${local.master_name}-backup-volume"
        VolumeType  = "database-backup"
        Purpose     = "postgresql-backup"
      }
    }
  ]

  # IAM configuration
  create_iam_role           = true
  enable_ssm               = true
  additional_iam_policies  = var.additional_iam_policies

  # Client identification
  client_name   = var.client_name
  service_type  = "database-master"
  environment   = var.environment

  tags = merge(local.common_tags, {
    Name = local.master_name
    Role = "database-master"
    DatabaseType = "postgresql-master"
  })
}

# ===================================================================================
# REPLICA DATABASE INSTANCE
# ===================================================================================

module "replica_instance" {
  count  = var.enable_replica ? 1 : 0
  source = "../ec2"

  # Instance configuration
  name                = local.replica_name
  ami_id              = var.ami_id
  instance_type       = var.replica_instance_type
  key_name            = var.key_name
  subnet_id           = var.replica_subnet_id
  security_groups     = [aws_security_group.postgres.id]
  associate_public_ip = false

  # Advanced configuration
  enable_monitoring          = var.enable_monitoring
  ebs_optimized             = true
  disable_api_termination   = var.enable_deletion_protection
  user_data_base64          = local.replica_user_data

  # Storage configuration
  volume_type                = var.root_volume_type
  volume_size               = var.root_volume_size
  volume_iops               = var.root_volume_iops
  volume_throughput         = var.root_volume_throughput
  root_volume_encrypted     = var.enable_encryption
  delete_root_on_termination = false
  kms_key_id               = var.kms_key_id

  # Additional EBS volumes for PostgreSQL data (replica)
  extra_volumes = [
    {
      device_name = "/dev/sdf"
      name        = "data-volume"
      size        = var.data_volume_size
      type        = var.data_volume_type
      iops        = var.data_volume_iops
      throughput  = var.data_volume_throughput
      encrypted   = var.enable_encryption
      kms_key_id  = var.kms_key_id
      tags = {
        Name        = "${local.replica_name}-data-volume"
        VolumeType  = "database-data"
        Purpose     = "postgresql-data"
      }
    },
    {
      device_name = "/dev/sdg"
      name        = "wal-volume"
      size        = var.wal_volume_size
      type        = var.wal_volume_type
      iops        = var.wal_volume_iops
      throughput  = var.wal_volume_throughput
      encrypted   = var.enable_encryption
      kms_key_id  = var.kms_key_id
      tags = {
        Name        = "${local.replica_name}-wal-volume"
        VolumeType  = "database-wal"
        Purpose     = "postgresql-wal"
      }
    }
  ]

  # IAM configuration
  create_iam_role           = true
  enable_ssm               = true
  additional_iam_policies  = var.additional_iam_policies

  # Client identification
  client_name   = var.client_name
  service_type  = "database-replica"
  environment   = var.environment

  tags = merge(local.common_tags, {
    Name = local.replica_name
    Role = "database-replica"
    DatabaseType = "postgresql-replica"
  })

  # Ensure replica starts after master
  depends_on = [module.master_instance]
}

# ===================================================================================
# ROUTE 53 PRIVATE HOSTED ZONE RECORDS (OPTIONAL)
# ===================================================================================

resource "aws_route53_record" "master" {
  count   = var.create_dns_records ? 1 : 0
  zone_id = var.private_zone_id
  name    = "${var.client_name}-db-master.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [module.master_instance.private_ip]

}

resource "aws_route53_record" "replica" {
  count   = var.enable_replica && var.create_dns_records ? 1 : 0
  zone_id = var.private_zone_id
  name    = "${var.client_name}-db-replica.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [module.replica_instance[0].private_ip]

}

# ===================================================================================
# SSM PARAMETERS FOR DATABASE CONNECTIVITY
# ===================================================================================

resource "aws_ssm_parameter" "master_endpoint" {
  name  = "/terraform/${var.environment}/${var.client_name}/database/master/endpoint"
  type  = "String"
  value = var.create_dns_records ? aws_route53_record.master[0].name : module.master_instance.private_ip
  
  tags = merge(local.common_tags, {
    Name = "${var.client_name}-db-master-endpoint"
    Type = "ssm-parameter"
  })
}

resource "aws_ssm_parameter" "replica_endpoint" {
  count = var.enable_replica ? 1 : 0
  name  = "/terraform/${var.environment}/${var.client_name}/database/replica/endpoint"
  type  = "String"
  value = var.create_dns_records ? aws_route53_record.replica[0].name : module.replica_instance[0].private_ip
  
  tags = merge(local.common_tags, {
    Name = "${var.client_name}-db-replica-endpoint"
    Type = "ssm-parameter"
  })
}

resource "aws_ssm_parameter" "database_port" {
  name  = "/terraform/${var.environment}/${var.client_name}/database/port"
  type  = "String"
  value = tostring(var.postgres_port)
  
  tags = merge(local.common_tags, {
    Name = "${var.client_name}-db-port"
    Type = "ssm-parameter"
  })
}

resource "aws_ssm_parameter" "database_name" {
  name  = "/terraform/${var.environment}/${var.client_name}/database/name"
  type  = "String"
  value = var.database_name
  
  tags = merge(local.common_tags, {
    Name = "${var.client_name}-db-name"
    Type = "ssm-parameter"
  })
}
