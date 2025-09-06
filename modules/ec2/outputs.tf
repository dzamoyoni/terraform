# ============================================================================
# EC2 Module Outputs
# ============================================================================
# Comprehensive outputs for EC2 instance and associated resources
# providing all necessary information for downstream dependencies
# ============================================================================

# ===================================================================================
# INSTANCE OUTPUTS
# ===================================================================================

output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.main.id
}

output "instance_arn" {
  description = "The ARN of the EC2 instance"
  value       = aws_instance.main.arn
}

output "instance_state" {
  description = "The state of the EC2 instance"
  value       = aws_instance.main.instance_state
}

output "instance_type" {
  description = "The type of the EC2 instance"
  value       = aws_instance.main.instance_type
}

output "ami_id" {
  description = "The AMI ID used for the EC2 instance"
  value       = aws_instance.main.ami
}

# ===================================================================================
# NETWORKING OUTPUTS
# ===================================================================================

output "private_ip" {
  description = "The private IP address of the EC2 instance"
  value       = aws_instance.main.private_ip
}

output "public_ip" {
  description = "The public IP address of the EC2 instance (if applicable)"
  value       = aws_instance.main.public_ip
}

output "private_dns" {
  description = "The private DNS name of the EC2 instance"
  value       = aws_instance.main.private_dns
}

output "public_dns" {
  description = "The public DNS name of the EC2 instance (if applicable)"
  value       = aws_instance.main.public_dns
}

output "subnet_id" {
  description = "The subnet ID where the instance is deployed"
  value       = aws_instance.main.subnet_id
}

output "vpc_id" {
  description = "The VPC ID where the instance is deployed"
  value       = data.aws_vpc.selected.id
}

output "availability_zone" {
  description = "The availability zone where the instance is deployed"
  value       = aws_instance.main.availability_zone
}

output "security_group_ids" {
  description = "List of security group IDs attached to the instance"
  value       = aws_instance.main.vpc_security_group_ids
}

# ===================================================================================
# STORAGE OUTPUTS
# ===================================================================================

output "root_volume_id" {
  description = "The ID of the root EBS volume"
  value       = aws_instance.main.root_block_device[0].volume_id
}

output "root_volume_arn" {
  description = "The ARN of the root EBS volume"
  value       = "arn:aws:ec2:${data.aws_subnet.selected.availability_zone}:${data.aws_vpc.selected.owner_id}:volume/${aws_instance.main.root_block_device[0].volume_id}"
}

output "additional_volume_ids" {
  description = "List of additional EBS volume IDs"
  value       = aws_ebs_volume.additional[*].id
}

output "additional_volume_arns" {
  description = "List of additional EBS volume ARNs"
  value       = aws_ebs_volume.additional[*].arn
}

output "volume_attachments" {
  description = "Map of volume attachments with device names and volume IDs"
  value = {
    for i, attachment in aws_volume_attachment.additional : 
    attachment.device_name => {
      volume_id     = attachment.volume_id
      attachment_id = attachment.id
      device_name   = attachment.device_name
    }
  }
}

# ===================================================================================
# IAM OUTPUTS
# ===================================================================================

output "iam_role_arn" {
  description = "The ARN of the IAM role (if created)"
  value       = var.create_iam_role ? aws_iam_role.instance_role[0].arn : null
}

output "iam_role_name" {
  description = "The name of the IAM role (if created)"
  value       = var.create_iam_role ? aws_iam_role.instance_role[0].name : null
}

output "iam_instance_profile_arn" {
  description = "The ARN of the IAM instance profile (if created)"
  value       = var.create_iam_role ? aws_iam_instance_profile.instance_profile[0].arn : null
}

output "iam_instance_profile_name" {
  description = "The name of the IAM instance profile (if created or provided)"
  value       = var.create_iam_role ? aws_iam_instance_profile.instance_profile[0].name : var.iam_instance_profile
}

# ===================================================================================
# SECURITY GROUP OUTPUTS
# ===================================================================================

output "default_security_group_id" {
  description = "The ID of the default security group (if created)"
  value       = var.create_default_security_group ? aws_security_group.default[0].id : null
}

output "default_security_group_arn" {
  description = "The ARN of the default security group (if created)"
  value       = var.create_default_security_group ? aws_security_group.default[0].arn : null
}

# ===================================================================================
# METADATA OUTPUTS
# ===================================================================================

output "tags" {
  description = "A map of tags assigned to the EC2 instance"
  value       = aws_instance.main.tags
}

output "instance_name" {
  description = "The name of the EC2 instance"
  value       = local.instance_name
}

# ===================================================================================
# MONITORING AND MANAGEMENT OUTPUTS
# ===================================================================================

output "monitoring_enabled" {
  description = "Whether detailed monitoring is enabled"
  value       = aws_instance.main.monitoring
}

output "ebs_optimized" {
  description = "Whether EBS optimization is enabled"
  value       = aws_instance.main.ebs_optimized
}

output "key_name" {
  description = "The key pair name used for the instance"
  value       = aws_instance.main.key_name
}

# ===================================================================================
# COMPATIBILITY OUTPUTS
# ===================================================================================
# These outputs provide compatibility with existing client-infrastructure usage

output "database_instance_id" {
  description = "Compatibility alias for instance_id (for database use cases)"
  value       = aws_instance.main.id
}

output "database_private_ip" {
  description = "Compatibility alias for private_ip (for database use cases)"
  value       = aws_instance.main.private_ip
}

output "database_security_group_id" {
  description = "Compatibility alias for default security group ID"
  value       = var.create_default_security_group ? aws_security_group.default[0].id : null
}

# ===================================================================================
# SUMMARY OUTPUT
# ===================================================================================

output "instance_summary" {
  description = "Complete summary of the EC2 instance and associated resources"
  value = {
    # Instance details
    instance = {
      id               = aws_instance.main.id
      arn              = aws_instance.main.arn
      name             = local.instance_name
      type             = aws_instance.main.instance_type
      ami              = aws_instance.main.ami
      state            = aws_instance.main.instance_state
      availability_zone = aws_instance.main.availability_zone
    }
    
    # Network details
    network = {
      vpc_id            = data.aws_vpc.selected.id
      subnet_id         = aws_instance.main.subnet_id
      private_ip        = aws_instance.main.private_ip
      public_ip         = aws_instance.main.public_ip
      private_dns       = aws_instance.main.private_dns
      public_dns        = aws_instance.main.public_dns
      security_groups   = aws_instance.main.vpc_security_group_ids
    }
    
    # Storage details
    storage = {
      root_volume_id       = aws_instance.main.root_block_device[0].volume_id
      additional_volumes   = aws_ebs_volume.additional[*].id
      volume_attachments   = [for attachment in aws_volume_attachment.additional : {
        device_name = attachment.device_name
        volume_id   = attachment.volume_id
      }]
    }
    
    # IAM details
    iam = {
      role_created           = var.create_iam_role
      role_name              = var.create_iam_role ? aws_iam_role.instance_role[0].name : null
      instance_profile_name  = var.create_iam_role ? aws_iam_instance_profile.instance_profile[0].name : var.iam_instance_profile
    }
    
    # Configuration
    configuration = {
      monitoring_enabled         = aws_instance.main.monitoring
      ebs_optimized             = aws_instance.main.ebs_optimized
      disable_api_termination   = aws_instance.main.disable_api_termination
      key_name                  = aws_instance.main.key_name
      service_type              = var.service_type
      client_name               = var.client_name
    }
  }
}
