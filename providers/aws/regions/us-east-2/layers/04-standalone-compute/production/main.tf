# =============================================================================
# Standalone Compute Layer - Client-Subnet-Scoped Analytics Instances
# =============================================================================
# This layer creates analytics EC2 instances that are strictly scoped to
# specific client subnets for maximum isolation and security.
#
# Key Features:
# - Analytics instances accessible only within client subnets
# - Client-specific security groups with subnet CIDR restrictions
# - No cross-client network access
# - Integrated with existing foundation and platform layers
# =============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.1"
    }
  }
  
  backend "s3" {
    # Backend configuration loaded from backend.hcl
  }
}

# =============================================================================
# Provider Configuration
# =============================================================================

# TAGGING STRATEGY: Provider-level default tags for consistency
# All AWS resources will automatically inherit tags from provider configuration
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      # Core identification
      Project         = var.project_name
      Environment     = var.environment
      Region          = var.region
      
      # Operational
      ManagedBy       = "Terraform"
      Layer           = "04-Standalone-Compute"
      DeploymentPhase = "Layer-4"
      
      # Governance
      CriticalInfra   = "false"
      BackupRequired  = "true"
      SecurityLevel   = "High"
      
      # Cost Management
      CostCenter      = "IT-Infrastructure"
      BillingGroup    = "Platform-Engineering"
      
      # Platform specific
      ClusterRole     = "Primary"
      PlatformType    = "Analytics"
    }
  }
}

# =============================================================================
# Data Sources
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# DATA SOURCES - Foundation and Platform Layer Outputs
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

# Get subnet details for CIDR information
data "aws_subnet" "client_subnets" {
  for_each = toset(local.all_client_subnet_ids)
  id       = each.value
}

# =============================================================================
# Local Values
# =============================================================================

# LOCALS - Foundation Layer Data with Validation
locals {
  # Foundation layer outputs
  vpc_id             = data.terraform_remote_state.foundation.outputs.vpc_id
  vpc_cidr_block     = data.terraform_remote_state.foundation.outputs.vpc_cidr_block
  
  # Dynamic client subnet lookup - automatically discovers available client subnets
  available_client_subnets = {
    for client_key, value in data.terraform_remote_state.foundation.outputs :
    replace(client_key, "_compute_subnet_ids", "") => value
    if can(regex("^est_test_[a-z]_compute_subnet_ids$", client_key))
  }
  
  # Transform keys to use hyphens (client naming convention)
  client_subnets = {
    for client_key, subnet_ids in local.available_client_subnets :
    replace(client_key, "_", "-") => subnet_ids
  }
  
  # Flatten all subnet IDs for data source
  all_client_subnet_ids = flatten([for subnet_ids in values(local.client_subnets) : subnet_ids])
  
  # Platform layer integration
  cluster_name = data.terraform_remote_state.platform.outputs.cluster_name
  
  # Foundation layer metadata for validation
  foundation_project_name = try(data.terraform_remote_state.foundation.outputs.project_name, "")
  foundation_environment  = try(data.terraform_remote_state.foundation.outputs.environment, "")
  foundation_region      = try(data.terraform_remote_state.foundation.outputs.region, "")
  
  # Client-specific configurations - dynamically built based on available foundation subnets
  client_configs = {
    for client in keys(var.analytics_configs) : client => {
      # Ensure client has foundation subnets available
      subnet_ids = lookup(local.client_subnets, client, [])
      # Get CIDR blocks for these subnets  
      subnet_cidrs = [
        for subnet_id in lookup(local.client_subnets, client, []) :
        data.aws_subnet.client_subnets[subnet_id].cidr_block
      ]
      instance_type = var.analytics_configs[client].instance_type
      root_volume_size = var.analytics_configs[client].root_volume_size
      data_volume_size = var.analytics_configs[client].data_volume_size
    } if length(lookup(local.client_subnets, client, [])) > 0  # Only include clients with available subnets
  }

  # Only deploy for enabled clients
  active_clients = {
    for client, config in local.client_configs :
    client => config
    if contains(var.enabled_clients, client)
  }
  
  # Cross-layer validation
  foundation_compatibility_check = {
    project_name_match = local.foundation_project_name == "" || local.foundation_project_name == var.project_name
    environment_match  = local.foundation_environment == "" || local.foundation_environment == var.environment
    region_match       = local.foundation_region == "" || local.foundation_region == var.region
    vpc_exists         = local.vpc_id != null && local.vpc_id != ""
    compute_subnets_exist = length(local.all_client_subnet_ids) >= 1
    enabled_clients_have_subnets = alltrue([
      for client in var.enabled_clients :
      length(lookup(local.client_subnets, client, [])) > 0
    ])
  }
}

# =============================================================================
# Latest Amazon Linux AMI
# =============================================================================

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# =============================================================================
# Client-Scoped Security Groups
# =============================================================================

resource "aws_security_group" "client_analytics" {
  for_each = local.active_clients
  
  name_prefix = "${replace(each.key, "-", "_")}-analytics-sg-"
  description = "Security group for ${each.key} analytics instances - subnet-scoped access only"
  vpc_id      = local.vpc_id

  # SSH access only from client-specific subnets
  ingress {
    description = "SSH access from ${each.key} subnets only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = each.value.subnet_cidrs
  }

  # Analytics application ports (Jupyter, etc.) - client subnet only
  ingress {
    description = "Analytics application ports from ${each.key} subnets only"
    from_port   = 8888
    to_port     = 8890
    protocol    = "tcp"
    cidr_blocks = each.value.subnet_cidrs
  }

  # Custom application port - client subnet only
  ingress {
    description = "Custom analytics port from ${each.key} subnets only"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = each.value.subnet_cidrs
  }

  # Database access (to client's own database) - client subnet only
  ingress {
    description = "Database access from ${each.key} subnets only"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = each.value.subnet_cidrs
  }

  # All outbound traffic (for package installation, etc.)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name              = "${replace(each.key, "-", "_")}-analytics-sg"
    Client            = each.key
    Purpose           = "analytics-compute"
    NetworkScope      = "client-subnet-only"
    Type              = "security-group"
  }
}

# =============================================================================
# IAM Role for Analytics Instances
# =============================================================================

resource "aws_iam_role" "analytics_instance" {
  for_each = local.active_clients
  
  name = "${replace(each.key, "-", "_")}_analytics_instance_role"

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

  tags = {
    Name    = "${replace(each.key, "-", "_")}_analytics_instance_role"
    Client  = each.key
    Purpose = "analytics-compute"
    Type    = "iam-role"
  }
}

resource "aws_iam_instance_profile" "analytics_instance" {
  for_each = local.active_clients
  
  name = "${replace(each.key, "-", "_")}_analytics_instance_profile"
  role = aws_iam_role.analytics_instance[each.key].name

  tags = {
    Name    = "${replace(each.key, "-", "_")}_analytics_instance_profile"
    Client  = each.key
    Purpose = "analytics-compute"
    Type    = "instance-profile"
  }
}

# Attach essential managed policies
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  for_each = local.active_clients
  
  role       = aws_iam_role.analytics_instance[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  for_each = local.active_clients
  
  role       = aws_iam_role.analytics_instance[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# =============================================================================
# Analytics EC2 Instance
# =============================================================================

resource "aws_instance" "client_analytics" {
  for_each = local.active_clients
  
  ami                     = data.aws_ami.amazon_linux.id
  instance_type          = each.value.instance_type
  key_name               = "ohio-01-keypair"  # Using existing key pair
  subnet_id              = each.value.subnet_ids[0]  # Deploy to first subnet
  vpc_security_group_ids = [aws_security_group.client_analytics[each.key].id]
  iam_instance_profile   = aws_iam_instance_profile.analytics_instance[each.key].name

  # Disable public IP assignment
  associate_public_ip_address = false
  
  # Enhanced monitoring
  monitoring = true
  
  # Instance metadata options for security
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 2
  }

  # Root volume configuration
  root_block_device {
    volume_type           = "gp3"
    volume_size           = each.value.root_volume_size
    encrypted             = true
    delete_on_termination = false
    iops                  = 3000
    throughput            = 125
    
    tags = {
      Name         = "${replace(each.key, "-", "_")}_analytics_root_volume"
      Client       = each.key
      Purpose      = "analytics-compute"
      VolumeType   = "root"
    }
  }

  # Analytics data volume
  ebs_block_device {
    device_name           = "/dev/xvdf"
    volume_type           = "gp3"
    volume_size           = each.value.data_volume_size
    encrypted             = true
    delete_on_termination = false
    iops                  = 4000
    throughput            = 250

    tags = {
      Name         = "${replace(each.key, "-", "_")}_analytics_data_volume"
      Client       = each.key
      Purpose      = "analytics-data"
      VolumeType   = "data"
    }
  }

  user_data = base64encode(templatefile("${path.module}/templates/analytics-userdata.sh", {
    CLIENT_NAME  = each.key
    REGION       = var.region
    ENVIRONMENT  = var.environment
    VPC_CIDR     = local.vpc_cidr_block
  }))

  tags = {
    Name                = "${replace(each.key, "-", "_")}_analytics_instance"
    Client              = each.key
    Purpose             = "analytics-compute"
    NetworkScope        = "client-subnet-only"
    HighAvailability    = "false"
    MonitoringEnabled   = "true"
  }
}

# =============================================================================
# SSM Parameters for Client Discovery
# =============================================================================

resource "aws_ssm_parameter" "analytics_endpoint" {
  for_each = local.active_clients
  
  name  = "/terraform/${var.environment}/${each.key}/analytics/endpoint"
  type  = "String"
  value = aws_instance.client_analytics[each.key].private_ip

  tags = {
    Name    = "${each.key}_analytics_endpoint"
    Client  = each.key
    Purpose = "analytics-discovery"
    Type    = "ssm-parameter"
  }
}

resource "aws_ssm_parameter" "analytics_instance_id" {
  for_each = local.active_clients
  
  name  = "/terraform/${var.environment}/${each.key}/analytics/instance-id"
  type  = "String"
  value = aws_instance.client_analytics[each.key].id

  tags = {
    Name    = "${each.key}_analytics_instance_id"
    Client  = each.key
    Purpose = "analytics-discovery"
    Type    = "ssm-parameter"
  }
}

# VALIDATION CHECKS
resource "null_resource" "cross_layer_validation" {
  # Ensure foundation layer is compatible
  lifecycle {
    precondition {
      condition     = local.foundation_compatibility_check.vpc_exists
      error_message = "VPC from foundation layer is missing. Ensure foundation layer is applied successfully."
    }
    
    precondition {
      condition     = local.foundation_compatibility_check.compute_subnets_exist
      error_message = "Compute subnets from foundation layer are missing. Check foundation layer outputs."
    }
    
    precondition {
      condition     = local.foundation_compatibility_check.project_name_match
      error_message = "Project name mismatch between foundation (${local.foundation_project_name}) and standalone-compute (${var.project_name}) layers."
    }
    
    precondition {
      condition     = local.foundation_compatibility_check.environment_match
      error_message = "Environment mismatch between foundation (${local.foundation_environment}) and standalone-compute (${var.environment}) layers."
    }
    
    precondition {
      condition     = local.foundation_compatibility_check.region_match
      error_message = "Region mismatch between foundation (${local.foundation_region}) and standalone-compute (${var.region}) layers."
    }
    
    precondition {
      condition     = local.foundation_compatibility_check.enabled_clients_have_subnets
      error_message = "Some enabled clients do not have compute subnets in foundation layer. Available clients: [${join(", ", keys(local.client_subnets))}]. Enabled clients: [${join(", ", var.enabled_clients)}]."
    }
  }
  
  triggers = {
    foundation_state_version = try(data.terraform_remote_state.foundation.outputs.state_version, timestamp())
    platform_state_version   = try(data.terraform_remote_state.platform.outputs.cluster_name, timestamp())
    compute_config_version  = md5(jsonencode({
      project_name = var.project_name
      environment  = var.environment
      region       = var.region
    }))
  }
}
