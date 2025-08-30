# MTN Ghana Database Outputs
output "mtn_ghana_database_id" {
  description = "MTN Ghana database instance ID"
  value       = aws_instance.mtn_ghana_db.id
}

output "mtn_ghana_database_private_ip" {
  description = "MTN Ghana database private IP"
  value       = aws_instance.mtn_ghana_db.private_ip
}

output "mtn_ghana_database_private_dns" {
  description = "MTN Ghana database private DNS"
  value       = aws_instance.mtn_ghana_db.private_dns
}

output "mtn_ghana_extra_volume_id" {
  description = "MTN Ghana extra volume ID"
  value       = aws_ebs_volume.mtn_ghana_extra.id
}

output "mtn_ghana_iam_role_arn" {
  description = "MTN Ghana IAM role ARN"
  value       = aws_iam_role.mtn_ghana_role.arn
}

# Ezra Database Outputs
output "ezra_database_id" {
  description = "Ezra database instance ID"
  value       = aws_instance.ezra_db.id
}

output "ezra_database_private_ip" {
  description = "Ezra database private IP"
  value       = aws_instance.ezra_db.private_ip
}

output "ezra_database_private_dns" {
  description = "Ezra database private DNS"
  value       = aws_instance.ezra_db.private_dns
}

output "ezra_extra_volume_id" {
  description = "Ezra extra volume ID"
  value       = aws_ebs_volume.ezra_extra.id
}

output "ezra_iam_role_arn" {
  description = "Ezra IAM role ARN"
  value       = aws_iam_role.ezra_role.arn
}

# Database Layer Summary
output "database_layer_summary" {
  description = "Summary of database layer resources"
  value = {
    layer       = var.layer
    environment = var.environment
    region      = var.region
    
    mtn_ghana = {
      instance_id  = aws_instance.mtn_ghana_db.id
      private_ip   = aws_instance.mtn_ghana_db.private_ip
      volume_id    = aws_ebs_volume.mtn_ghana_extra.id
      iam_role     = aws_iam_role.mtn_ghana_role.name
    }
    
    ezra = {
      instance_id  = aws_instance.ezra_db.id
      private_ip   = aws_instance.ezra_db.private_ip
      volume_id    = aws_ebs_volume.ezra_extra.id
      iam_role     = aws_iam_role.ezra_role.name
    }
  }
}

# SSM Parameter Store Outputs for Inter-Layer Communication
resource "aws_ssm_parameter" "mtn_ghana_database_ip" {
  name  = "/infrastructure/databases/${var.environment}/mtn_ghana_database_ip"
  type  = "String"
  value = aws_instance.mtn_ghana_db.private_ip
  
  tags = {
    Environment = var.environment
    Layer       = var.layer
    ManagedBy   = "terraform"
    Purpose     = "inter-layer-communication"
  }
}

resource "aws_ssm_parameter" "ezra_database_ip" {
  name  = "/infrastructure/databases/${var.environment}/ezra_database_ip"
  type  = "String"
  value = aws_instance.ezra_db.private_ip
  
  tags = {
    Environment = var.environment
    Layer       = var.layer
    ManagedBy   = "terraform"
    Purpose     = "inter-layer-communication"
  }
}

resource "aws_ssm_parameter" "database_instance_ids" {
  name  = "/infrastructure/databases/${var.environment}/instance_ids"
  type  = "StringList"
  value = join(",", [
    aws_instance.mtn_ghana_db.id,
    aws_instance.ezra_db.id
  ])
  
  tags = {
    Environment = var.environment
    Layer       = var.layer
    ManagedBy   = "terraform"
    Purpose     = "inter-layer-communication"
  }
}
