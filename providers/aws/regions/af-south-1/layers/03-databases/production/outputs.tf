# 📱 MTN GHANA DATABASE OUTPUTS
output "mtn_ghana_database_id" {
  description = "MTN Ghana database instance ID"
  value       = aws_instance.mtn_ghana_db_prod.id
}

output "mtn_ghana_database_private_ip" {
  description = "MTN Ghana database private IP"
  value       = aws_instance.mtn_ghana_db_prod.private_ip
}

output "mtn_ghana_database_private_dns" {
  description = "MTN Ghana database private DNS"
  value       = aws_instance.mtn_ghana_db_prod.private_dns
}

output "mtn_ghana_extra_volume_id" {
  description = "MTN Ghana extra volume ID"
  value       = aws_ebs_volume.mtn_ghana_extra_prod.id
}

# output "mtn_ghana_extra2_volume_id" {
#   description = "MTN Ghana second extra volume ID (logs)"
#   value       = aws_ebs_volume.mtn_ghana_extra2_prod.id
# }

output "mtn_ghana_iam_role_arn" {
  description = "MTN Ghana IAM role ARN"
  value       = aws_iam_role.mtn_ghana_role.arn
}

# 🍊 ORANGE MADAGASCAR DATABASE OUTPUTS (commented out as resources are not deployed)
# output "orange_madagascar_database_id" {
#   description = "Orange Madagascar database instance ID"
#   value       = aws_instance.orange_madagascar_db.id
# }

# output "orange_madagascar_database_private_ip" {
#   description = "Orange Madagascar database private IP"
#   value       = aws_instance.orange_madagascar_db.private_ip
# }

# output "orange_madagascar_database_private_dns" {
#   description = "Orange Madagascar database private DNS"
#   value       = aws_instance.orange_madagascar_db.private_dns
# }

# output "orange_madagascar_extra_volume_id" {
#   description = "Orange Madagascar extra volume ID"
#   value       = aws_ebs_volume.orange_madagascar_extra.id
# }

# output "orange_madagascar_iam_role_arn" {
#   description = "Orange Madagascar IAM role ARN"
#   value       = aws_iam_role.orange_madagascar_role.arn
# }

# 📊 DATABASE LAYER SUMMARY
output "database_layer_summary" {
  description = "Summary of database layer resources for AF-South-1"
  value = {
    layer       = "databases"
    environment = var.environment
    region      = var.region
    cluster     = local.cluster_name
    
    mtn_ghana_prod = {
      instance_id       = aws_instance.mtn_ghana_db_prod.id
      private_ip        = aws_instance.mtn_ghana_db_prod.private_ip
      private_dns       = aws_instance.mtn_ghana_db_prod.private_dns
      data_volume_id    = aws_ebs_volume.mtn_ghana_extra_prod.id
      # logs_volume_id    = aws_ebs_volume.mtn_ghana_extra2_prod.id  # Commented out for initial deployment
      iam_role          = aws_iam_role.mtn_ghana_role.name
      subnet_id         = local.mtn_ghana_database_subnet_id
      security_group    = local.mtn_ghana_database_security_group
      availability_zone = local.availability_zones[0]
    }
    
    # orange_madagascar_prod resources are commented out in main.tf
    # orange_madagascar_prod = {
    #   instance_id       = aws_instance.orange_madagascar_db.id
    #   private_ip        = aws_instance.orange_madagascar_db.private_ip
    #   private_dns       = aws_instance.orange_madagascar_db.private_dns
    #   volume_id         = aws_ebs_volume.orange_madagascar_extra.id
    #   iam_role          = aws_iam_role.orange_madagascar_role.name
    #   subnet_id         = local.orange_madagascar_database_subnet_id
    #   security_group    = local.orange_madagascar_database_security_group
    #   availability_zone = local.availability_zones[0]
    # }
  }
}

# 🔐 SECURITY NOTICE
output "security_notice" {
  description = "CPTWN database security notice and guidance"
  value = {
    message = "CPTWN Database Layer deployed with security best practices"
    documentation = "https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-security.html"
    actions_required = [
      "Configure database software on EC2 instances via SSM",
      "Set up automated backup scripts",
      "Configure CloudWatch monitoring and alerting",
      "Test database connectivity from EKS pods",
      "Implement database security hardening",
      "Configure log rotation and retention"
    ]
  }
}

# 📊 SSM PARAMETER STORE OUTPUTS FOR INTER-LAYER COMMUNICATION
resource "aws_ssm_parameter" "mtn_ghana_database_ip" {
  name  = "/cptwn/${var.environment}/databases/mtn-ghana-prod/private-ip"
  type  = "String"
  value = aws_instance.mtn_ghana_db_prod.private_ip
  
  tags = merge(local.cptwn_tags, {
    Name    = "mtn-ghana-prod-database-ip"
    Purpose = "inter-layer-communication"
    Client  = "mtn-ghana-prod"
  })
}

# resource "aws_ssm_parameter" "orange_madagascar_database_ip" {
#   name  = "/cptwn/${var.environment}/databases/orange-madagascar-prod/private-ip"
#   type  = "String"
#   value = aws_instance.orange_madagascar_db.private_ip
#   
#   tags = merge(local.cptwn_tags, {
#     Name    = "orange-madagascar-prod-database-ip"
#     Purpose = "inter-layer-communication"
#     Client  = "orange-madagascar-prod"
#   })
# }

resource "aws_ssm_parameter" "database_instance_ids" {
  name  = "/cptwn/${var.environment}/databases/instance-ids"
  type  = "StringList"
  value = aws_instance.mtn_ghana_db_prod.id
  
  tags = merge(local.cptwn_tags, {
    Name    = "database-instance-ids"
    Purpose = "inter-layer-communication"
  })
}
