# ============================================================================
# AF-South-1 PostgreSQL on EC2 - High Availability Database Deployment
# ============================================================================
# This example shows how to use the new postgres-ec2 module in af-south-1
# replacing manual EC2 instances with HA PostgreSQL setup
# ============================================================================

# 🇿🇦 MTN GHANA PRODUCTION DATABASE - HA Setup
module "mtn_ghana_database" {
  source = "../../../../../modules/postgres-ec2"

  # Client identification
  client_name = "mtn-ghana-prod"
  environment = var.environment

  # Network configuration - using existing AF-South-1 subnets
  vpc_id            = local.vpc_id
  master_subnet_id  = local.mtn_ghana_database_subnet_id                                                   # af-south-1a
  replica_subnet_id = data.terraform_remote_state.foundation.outputs.mtn_ghana_prod_database_subnet_ids[1] # af-south-1b

  # Instance configuration
  ami_id                = data.aws_ami.debian.id
  key_name              = var.key_name
  master_instance_type  = "r5.large" # Production sizing
  replica_instance_type = "r5.large" # Match master for consistency

  # PostgreSQL configuration
  postgres_version     = "15"
  postgres_port        = 5432
  database_name        = "mtn_ghana_core"
  database_user        = "mtn_app_user"
  database_password    = var.mtn_ghana_db_password
  replication_user     = "mtn_replicator"
  replication_password = var.mtn_ghana_repl_password

  # High-performance storage for telecommunications workload
  data_volume_size       = var.mtn_ghana_config.volume_size # 50GB from existing config
  data_volume_type       = "gp3"
  data_volume_iops       = var.mtn_ghana_config.volume_iops # 10000 from existing config
  data_volume_throughput = 500

  wal_volume_size       = 20 # GB
  wal_volume_type       = "gp3"
  wal_volume_iops       = 5000
  wal_volume_throughput = 250

  backup_volume_size = 100 # GB for telecommunications data retention

  # Security configuration
  enable_encryption          = var.enable_encryption
  kms_key_id                 = local.kms_key_id
  enable_deletion_protection = true # Critical telecommunications data

  # Network access - using existing security groups
  allowed_cidr_blocks = [
    "172.16.12.0/22", # MTN Ghana client subnets
    "172.16.0.0/20",  # Platform subnets for EKS connectivity
  ]
  management_cidr_blocks = ["172.16.1.0/24"] # Management subnet
  monitoring_cidr_blocks = ["172.16.2.0/24"] # Monitoring subnet

  # Monitoring and backup
  enable_monitoring     = var.enable_monitoring
  backup_retention_days = 14 # 2 weeks retention for compliance

  # Additional IAM policies for AWS services integration
  additional_iam_policies = [
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]

  # Tags matching CPTWN standards
  tags = merge(local.cptwn_tags, {
    Name               = "mtn-ghana-prod-database-ha"
    Client             = "mtn-ghana-prod"
    BusinessUnit       = "telecommunications"
    CostCenter         = "mtn-ghana-production"
    Owner              = "mtn-ghana-database-team"
    DataClass          = "restricted"
    CriticalityLevel   = "critical"
    BackupSchedule     = var.mtn_ghana_config.backup_schedule
    MaintenanceWindow  = var.mtn_ghana_config.maintenance_window
    NodeGroup          = "database"
    ClientEKSConnected = "true"
    HAEnabled          = "true"
  })
}

# 🇲🇬 ORANGE MADAGASCAR PRODUCTION DATABASE - HA Setup  
module "orange_madagascar_database" {
  source = "../../../../../modules/postgres-ec2"

  # Client identification
  client_name = "orange-madagascar-prod"
  environment = var.environment

  # Network configuration - using existing AF-South-1 subnets
  vpc_id            = local.vpc_id
  master_subnet_id  = local.orange_madagascar_database_subnet_id                                                   # af-south-1a
  replica_subnet_id = data.terraform_remote_state.foundation.outputs.orange_madagascar_prod_database_subnet_ids[1] # af-south-1b

  # Instance configuration
  ami_id                = data.aws_ami.debian.id
  key_name              = var.key_name
  master_instance_type  = "r5.large" # Production sizing
  replica_instance_type = "r5.large" # Match master for consistency

  # PostgreSQL configuration
  postgres_version     = "15"
  postgres_port        = 5432
  database_name        = "orange_madagascar_core"
  database_user        = "orange_app_user"
  database_password    = var.orange_madagascar_db_password
  replication_user     = "orange_replicator"
  replication_password = var.orange_madagascar_repl_password

  # Storage configuration for telecommunications workload
  data_volume_size       = 100 # GB - larger for Orange Madagascar
  data_volume_type       = "gp3"
  data_volume_iops       = 5000
  data_volume_throughput = 250

  wal_volume_size       = 20 # GB
  wal_volume_type       = "gp3"
  wal_volume_iops       = 3000
  wal_volume_throughput = 125

  backup_volume_size = 100 # GB for telecommunications data retention

  # Security configuration
  enable_encryption          = var.enable_encryption
  kms_key_id                 = local.kms_key_id
  enable_deletion_protection = true # Critical telecommunications data

  # Network access - using client-specific subnets
  allowed_cidr_blocks = [
    "172.16.16.0/22", # Orange Madagascar client subnets
    "172.16.0.0/20",  # Platform subnets for EKS connectivity
  ]
  management_cidr_blocks = ["172.16.1.0/24"] # Management subnet
  monitoring_cidr_blocks = ["172.16.2.0/24"] # Monitoring subnet

  # Monitoring and backup
  enable_monitoring     = var.enable_monitoring
  backup_retention_days = 14 # 2 weeks retention for compliance

  # Additional IAM policies for AWS services integration
  additional_iam_policies = [
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]

  # Tags matching CPTWN standards
  tags = merge(local.cptwn_tags, {
    Name             = "orange-madagascar-prod-database-ha"
    Client           = "orange-madagascar-prod"
    BusinessUnit     = "telecommunications"
    CostCenter       = "orange-madagascar-production"
    Owner            = "orange-madagascar-database-team"
    DataClass        = "restricted"
    CriticalityLevel = "critical"
    HAEnabled        = "true"
  })
}

# ============================================================================
# SSM PARAMETERS FOR CLIENT APPLICATION CONNECTIVITY
# ============================================================================

# MTN Ghana database connection parameters
resource "aws_ssm_parameter" "mtn_ghana_database_endpoints" {
  for_each = {
    master_endpoint  = module.mtn_ghana_database.master_endpoint
    replica_endpoint = module.mtn_ghana_database.replica_endpoint
    database_port    = tostring(module.mtn_ghana_database.database_port)
    database_name    = module.mtn_ghana_database.database_name
  }

  name  = "/cptwn/${var.environment}/mtn-ghana-prod/database/${each.key}"
  type  = "String"
  value = each.value

  tags = merge(local.cptwn_tags, {
    Client = "mtn-ghana-prod"
    Type   = "database-connection"
  })
}

# Orange Madagascar database connection parameters
resource "aws_ssm_parameter" "orange_madagascar_database_endpoints" {
  for_each = {
    master_endpoint  = module.orange_madagascar_database.master_endpoint
    replica_endpoint = module.orange_madagascar_database.replica_endpoint
    database_port    = tostring(module.orange_madagascar_database.database_port)
    database_name    = module.orange_madagascar_database.database_name
  }

  name  = "/cptwn/${var.environment}/orange-madagascar-prod/database/${each.key}"
  type  = "String"
  value = each.value

  tags = merge(local.cptwn_tags, {
    Client = "orange-madagascar-prod"
    Type   = "database-connection"
  })
}

# ============================================================================
# CLOUDWATCH ALARMS FOR DATABASE MONITORING
# ============================================================================

# MTN Ghana database monitoring
resource "aws_cloudwatch_metric_alarm" "mtn_ghana_db_cpu" {
  alarm_name          = "mtn-ghana-prod-database-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors MTN Ghana production database CPU utilization"
  alarm_actions       = [aws_sns_topic.database_alerts.arn]

  dimensions = {
    InstanceId = module.mtn_ghana_database.master_instance_id
  }

  tags = merge(local.cptwn_tags, {
    Client = "mtn-ghana-prod"
    Type   = "database-alarm"
  })
}

# Orange Madagascar database monitoring
resource "aws_cloudwatch_metric_alarm" "orange_madagascar_db_cpu" {
  alarm_name          = "orange-madagascar-prod-database-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors Orange Madagascar production database CPU utilization"
  alarm_actions       = [aws_sns_topic.database_alerts.arn]

  dimensions = {
    InstanceId = module.orange_madagascar_database.master_instance_id
  }

  tags = merge(local.cptwn_tags, {
    Client = "orange-madagascar-prod"
    Type   = "database-alarm"
  })
}

# SNS topic for database alerts
resource "aws_sns_topic" "database_alerts" {
  name = "cptwn-af-south-1-database-alerts"

  tags = merge(local.cptwn_tags, {
    Purpose = "database-monitoring"
  })
}
