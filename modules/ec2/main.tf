# ============================================================================
# EC2 Module - Reusable EC2 Instance with Advanced Features
# ============================================================================
# This module provides a flexible, reusable EC2 instance with support for:
# - Multiple EBS volumes and attachments
# - IAM roles and instance profiles
# - Security groups and networking
# - CloudWatch monitoring and SSM access
# - Client-isolation patterns and tagging
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

# Data sources for dynamic configuration
data "aws_subnet" "selected" {
  id = var.subnet_id
}

data "aws_vpc" "selected" {
  id = data.aws_subnet.selected.vpc_id
}

# Local variables for consistent naming and configuration
locals {
  # Instance name and common identifiers
  instance_name = var.name

  # Common tags for all resources
  common_tags = merge(var.tags, {
    Name        = var.name
    ManagedBy   = "terraform"
    Module      = "ec2"
    Environment = var.environment
    Service     = var.service_type
  })

  # Additional tags if client name is provided
  client_tags = var.client_name != "" ? {
    Client = var.client_name
  } : {}

  # Final merged tags
  final_tags = merge(local.common_tags, local.client_tags)

  # Security groups - always include provided groups, optionally create default
  security_group_ids = var.create_default_security_group ? concat([aws_security_group.default[0].id], var.security_groups) : var.security_groups
}

# ===================================================================================
# DEFAULT SECURITY GROUP (OPTIONAL)
# ===================================================================================

resource "aws_security_group" "default" {
  count = var.create_default_security_group ? 1 : 0

  name_prefix = "${local.instance_name}-sg-"
  description = "Default security group for ${local.instance_name}"
  vpc_id      = data.aws_vpc.selected.id

  # SSH access from VPC
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
    description = "SSH from VPC"
  }

  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.final_tags, {
    Name = "${local.instance_name}-default-sg"
    Type = "security-group"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ===================================================================================
# IAM ROLE AND INSTANCE PROFILE (OPTIONAL)
# ===================================================================================

resource "aws_iam_role" "instance_role" {
  count = var.create_iam_role ? 1 : 0

  name = "${local.instance_name}-role"

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

  tags = merge(local.final_tags, {
    Name = "${local.instance_name}-role"
    Type = "iam-role"
  })
}

# Attach SSM managed policy if SSM is enabled
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  count = var.create_iam_role && var.enable_ssm ? 1 : 0

  role       = aws_iam_role.instance_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach CloudWatch agent policy if monitoring is enabled
resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  count = var.create_iam_role && var.enable_monitoring ? 1 : 0

  role       = aws_iam_role.instance_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Attach additional IAM policies
resource "aws_iam_role_policy_attachment" "additional_policies" {
  count = var.create_iam_role ? length(var.additional_iam_policies) : 0

  role       = aws_iam_role.instance_role[0].name
  policy_arn = var.additional_iam_policies[count.index]
}

resource "aws_iam_instance_profile" "instance_profile" {
  count = var.create_iam_role ? 1 : 0

  name = "${local.instance_name}-profile"
  role = aws_iam_role.instance_role[0].name

  tags = merge(local.final_tags, {
    Name = "${local.instance_name}-profile"
    Type = "instance-profile"
  })
}

# ===================================================================================
# EC2 INSTANCE
# ===================================================================================

resource "aws_instance" "main" {
  # Core instance configuration
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = local.security_group_ids
  associate_public_ip_address = var.associate_public_ip

  # Advanced instance settings
  disable_api_termination              = var.disable_api_termination
  disable_api_stop                     = var.disable_api_stop
  instance_initiated_shutdown_behavior = var.shutdown_behavior
  monitoring                           = var.enable_monitoring
  ebs_optimized                        = var.ebs_optimized

  # IAM instance profile
  iam_instance_profile = var.create_iam_role ? aws_iam_instance_profile.instance_profile[0].name : var.iam_instance_profile

  # User data script (use only one of user_data or user_data_base64)
  user_data                   = var.user_data_base64 != "" ? null : var.user_data
  user_data_base64            = var.user_data_base64 != "" ? var.user_data_base64 : null
  user_data_replace_on_change = var.user_data_replace_on_change

  # Root block device configuration
  root_block_device {
    volume_type           = var.volume_type
    volume_size           = var.volume_size
    iops                  = var.volume_iops
    throughput            = var.volume_throughput
    encrypted             = var.root_volume_encrypted
    kms_key_id            = var.kms_key_id
    delete_on_termination = var.delete_root_on_termination

    tags = merge(local.final_tags, {
      Name       = "${local.instance_name}-root-volume"
      VolumeType = "root"
    })
  }

  # Credit specification for burstable instances
  dynamic "credit_specification" {
    for_each = var.cpu_credits != "" ? [var.cpu_credits] : []
    content {
      cpu_credits = credit_specification.value
    }
  }

  # Set placement group if provided
  placement_group = var.placement_group != "" ? var.placement_group : null

  tags = local.final_tags

  # Lifecycle management - Note: lifecycle settings must be static
  # To use dynamic lifecycle settings, implement in calling configuration
}

# ===================================================================================
# ADDITIONAL EBS VOLUMES
# ===================================================================================

resource "aws_ebs_volume" "additional" {
  count = length(var.extra_volumes)

  availability_zone = aws_instance.main.availability_zone
  size              = var.extra_volumes[count.index].size
  type              = var.extra_volumes[count.index].type
  iops              = try(var.extra_volumes[count.index].iops, null)
  throughput        = try(var.extra_volumes[count.index].throughput, null)
  encrypted         = try(var.extra_volumes[count.index].encrypted, var.root_volume_encrypted)
  kms_key_id        = try(var.extra_volumes[count.index].kms_key_id, var.kms_key_id)
  snapshot_id       = try(var.extra_volumes[count.index].snapshot_id, null)

  tags = merge(
    local.final_tags,
    try(var.extra_volumes[count.index].tags, {}),
    {
      Name       = "${local.instance_name}-${try(var.extra_volumes[count.index].name, "extra-volume-${count.index + 1}")}"
      VolumeType = "additional"
    }
  )

  # Note: lifecycle prevent_destroy must be static, set in calling configuration if needed
}

resource "aws_volume_attachment" "additional" {
  count = length(var.extra_volumes)

  device_name = var.extra_volumes[count.index].device_name
  volume_id   = aws_ebs_volume.additional[count.index].id
  instance_id = aws_instance.main.id

  # Force detachment settings
  force_detach = try(var.extra_volumes[count.index].force_detach, false)
  skip_destroy = try(var.extra_volumes[count.index].skip_destroy, false)

  # Note: lifecycle prevent_destroy must be static, set in calling configuration if needed
}
