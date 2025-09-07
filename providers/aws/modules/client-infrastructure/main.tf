# Client Infrastructure Module
# Provides complete client lifecycle management with multi-service support

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Local variables for client configuration processing
locals {
  # Common tags for all client resources
  common_tags = merge(var.common_tags, {
    Client             = var.client_name
    ClientFullName     = var.client_config.full_name
    BusinessUnit       = var.client_config.business_unit
    CostCenter         = var.client_config.cost_center
    OwnerTeam          = var.client_config.owner_team
    DataClassification = var.client_config.data_class
    Environment        = var.environment
    Region             = var.aws_region
    ManagedBy          = "terraform"
    ModuleVersion      = "2.0.0"
  })
  
  # Client-specific security group naming
  client_sg_prefix = "${var.cluster_name}-${var.client_name}"
  
  # Flatten applications for dynamic creation
  enabled_applications = {
    for app_name, app_config in var.client_config.applications : app_name => app_config
    if app_config.enabled
  }
}

# ===================================================================================
# CLIENT-SPECIFIC SECURITY GROUPS
# ===================================================================================

# Client Database Security Group
resource "aws_security_group" "client_database" {
  count = var.client_config.database.enabled ? 1 : 0
  
  name_prefix = "${local.client_sg_prefix}-db-"
  description = "Security group for ${var.client_name} database server"
  vpc_id      = var.vpc_id

  # Database port access from VPC
  ingress {
    from_port   = var.client_config.database.port
    to_port     = var.client_config.database.port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Database access from VPC"
  }
  
  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "SSH from VPC"
  }
  
  # VPN access if enabled
  dynamic "ingress" {
    for_each = var.enable_vpn_access ? [1] : []
    content {
      from_port   = var.client_config.database.port
      to_port     = var.client_config.database.port
      protocol    = "tcp"
      cidr_blocks = var.vpn_client_cidrs
      description = "Database access from VPN"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name    = "${local.client_sg_prefix}-database-sg"
    Service = "database"
    Type    = "security-group"
  })
  
  lifecycle {
    create_before_destroy = true
  }
}

# Client Application Security Group
resource "aws_security_group" "client_applications" {
  count = length(local.enabled_applications) > 0 ? 1 : 0
  
  name_prefix = "${local.client_sg_prefix}-app-"
  description = "Security group for ${var.client_name} application servers"
  vpc_id      = var.vpc_id

  # Standard web ports
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTP from VPC"
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS from VPC"
  }
  
  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "SSH from VPC"
  }
  
  # Custom application ports
  dynamic "ingress" {
    for_each = var.client_config.custom_ports
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name    = "${local.client_sg_prefix}-application-sg"
    Service = "application"
    Type    = "security-group"
  })
  
  lifecycle {
    create_before_destroy = true
  }
}

# ===================================================================================
# CLIENT DATABASE SERVER
# ===================================================================================

module "client_database_server" {
  count = var.client_config.database.enabled ? 1 : 0
  
  source = "../ec2"
  
  # Instance configuration
  name                = "${var.client_name}-${var.environment}-database"
  ami_id              = var.database_ami_id
  instance_type       = var.client_config.database.instance_type
  key_name            = var.ec2_key_name
  security_groups     = concat(
    [aws_security_group.client_database[0].id],
    var.additional_security_groups
  )
  subnet_id           = var.private_subnets[var.client_config.database.subnet_index]
  associate_public_ip = false
  volume_size         = var.client_config.database.root_volume_size
  volume_type         = var.client_config.database.root_volume_type
  enable_ssm          = true
  
  # Enhanced security settings
  disable_api_termination = var.client_config.database.security.disable_api_termination
  disable_api_stop       = var.client_config.database.security.disable_api_stop
  enable_monitoring      = var.client_config.database.security.enable_monitoring
  shutdown_behavior      = var.client_config.database.security.shutdown_behavior
  
  # Storage configuration
  root_volume_encrypted   = var.client_config.database.root_volume_encrypted
  root_volume_iops       = var.client_config.database.root_volume_iops
  root_volume_throughput = var.client_config.database.root_volume_throughput
  extra_volumes          = var.client_config.database.extra_volumes

  # Client-specific metadata
  client_name         = var.client_name
  purpose            = "database"
  cost_center        = var.client_config.cost_center
  owner_team         = var.client_config.owner_team
  business_unit      = var.client_config.business_unit
  project_name       = var.client_config.database.project_name
  data_classification = var.client_config.data_class
  backup_schedule    = var.client_config.backup.schedule
  maintenance_window = var.client_config.database.maintenance_window
  
  # Tags
  tags = merge(local.common_tags, {
    Service          = "database"
    CriticalityLevel = var.client_config.database.criticality_level
    Purpose          = "database"
  })
}

# ===================================================================================
# CLIENT APPLICATION SERVERS
# ===================================================================================

module "client_application_servers" {
  for_each = local.enabled_applications
  
  source = "../ec2"
  
  # Instance configuration
  name                = "${var.client_name}-${var.environment}-${each.key}"
  ami_id              = var.application_ami_id
  instance_type       = each.value.instance_type
  key_name            = var.ec2_key_name
  security_groups     = concat(
    length(aws_security_group.client_applications) > 0 ? [aws_security_group.client_applications[0].id] : [],
    var.additional_security_groups
  )
  subnet_id           = var.private_subnets[each.value.subnet_index]
  associate_public_ip = false
  volume_size         = each.value.root_volume_size
  volume_type         = each.value.root_volume_type
  enable_ssm          = true
  
  # Enhanced security settings
  disable_api_termination = true
  disable_api_stop       = false
  enable_monitoring      = true
  shutdown_behavior      = "stop"
  
  # Storage configuration
  root_volume_encrypted = true
  extra_volumes        = each.value.extra_volumes

  # Client-specific metadata
  client_name         = var.client_name
  purpose            = "application"
  cost_center        = var.client_config.cost_center
  owner_team         = var.client_config.owner_team
  business_unit      = var.client_config.business_unit
  project_name       = "${var.client_name}-${each.key}"
  data_classification = var.client_config.data_class
  backup_schedule    = var.client_config.backup.schedule
  maintenance_window = each.value.maintenance_window
  
  # Tags
  tags = merge(local.common_tags, {
    Service          = "application"
    ApplicationName  = each.key
    CriticalityLevel = each.value.criticality_level
    Purpose          = "application"
  })
}

# ===================================================================================
# CLIENT MONITORING (Optional)
# ===================================================================================

# CloudWatch Dashboard for Client
resource "aws_cloudwatch_dashboard" "client_dashboard" {
  count = var.client_config.monitoring.enabled ? 1 : 0
  
  dashboard_name = "${var.client_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = concat(
            var.client_config.database.enabled ? [
              ["AWS/EC2", "CPUUtilization", "InstanceId", module.client_database_server[0].instance_id],
              [".", "MemoryUtilization", ".", "."],
              [".", "DiskSpaceUtilization", ".", "."]
            ] : [],
            [
              for app_key, app_module in module.client_application_servers : [
                ["AWS/EC2", "CPUUtilization", "InstanceId", app_module.instance_id]
              ]
            ]...
          )
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "${var.client_config.full_name} - Resource Utilization"
        }
      }
    ]
  })
  
  # Note: CloudWatch dashboards do not support tags
}

# Client-specific SNS Topic for Alerts
resource "aws_sns_topic" "client_alerts" {
  count = var.client_config.monitoring.enabled ? 1 : 0
  
  name = "${var.client_name}-${var.environment}-alerts"
  
  tags = merge(local.common_tags, {
    Name    = "${var.client_name}-alerts"
    Service = "monitoring"
    Type    = "sns-topic"
  })
}

# SNS Topic Subscription
resource "aws_sns_topic_subscription" "client_email_alerts" {
  count = var.client_config.monitoring.enabled && var.client_config.monitoring.alerting_email != "" ? 1 : 0
  
  topic_arn = aws_sns_topic.client_alerts[0].arn
  protocol  = "email"
  endpoint  = var.client_config.monitoring.alerting_email
}

# ===================================================================================
# CLIENT BACKUP POLICIES (Optional)
# ===================================================================================

# Client-specific EBS Snapshot Lifecycle Policy
resource "aws_dlm_lifecycle_policy" "client_backup" {
  count = var.client_config.backup.enabled ? 1 : 0
  
  description        = "Backup policy for ${var.client_config.full_name} EBS volumes"
  execution_role_arn = var.dlm_role_arn
  state             = "ENABLED"

  policy_details {
    resource_types   = ["VOLUME"]
    target_tags = {
      Client = var.client_name
    }

    schedule {
      name = "${var.client_name}-${var.environment}-backup"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = [var.client_config.backup.time]
      }

      retain_rule {
        count = var.client_config.backup.retention_days
      }

      tags_to_add = merge(local.common_tags, {
        Name       = "${var.client_name}-backup"
        BackupType = "automated"
      })

      copy_tags = true
    }
  }
  
  tags = merge(local.common_tags, {
    Name    = "${var.client_name}-backup-policy"
    Service = "backup"
    Type    = "dlm-policy"
  })
}
