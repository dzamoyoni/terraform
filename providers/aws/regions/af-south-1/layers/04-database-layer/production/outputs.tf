# ============================================================================
# Database Layer Outputs - AF-South-1 Production
# ============================================================================

# ===================================================================================
# MTN GHANA DATABASE OUTPUTS
# ===================================================================================

output "mtn_ghana_database_info" {
  description = "MTN Ghana PostgreSQL database connection information"
  value = {
    client_name   = module.mtn_ghana_postgres.client_name
    database_name = module.mtn_ghana_postgres.database_name
    database_port = module.mtn_ghana_postgres.database_port
    master_endpoint = {
      instance_id = module.mtn_ghana_postgres.master_instance_id
      private_ip  = module.mtn_ghana_postgres.master_private_ip
      dns_name    = module.mtn_ghana_postgres.master_dns_name
      endpoint    = module.mtn_ghana_postgres.master_endpoint
    }
    replica_endpoint = module.mtn_ghana_postgres.high_availability_enabled ? {
      instance_id = module.mtn_ghana_postgres.replica_instance_id
      private_ip  = module.mtn_ghana_postgres.replica_private_ip
      dns_name    = module.mtn_ghana_postgres.replica_dns_name
      endpoint    = module.mtn_ghana_postgres.replica_endpoint
    } : null
    security_group_id = module.mtn_ghana_postgres.security_group_id
    high_availability = module.mtn_ghana_postgres.high_availability_enabled
  }
}

output "mtn_ghana_storage_info" {
  description = "MTN Ghana database storage information"
  value = {
    master_volumes = {
      data_volume_id   = module.mtn_ghana_postgres.master_data_volume_id
      wal_volume_id    = module.mtn_ghana_postgres.master_wal_volume_id
      backup_volume_id = module.mtn_ghana_postgres.master_backup_volume_id
    }
    replica_volumes = module.mtn_ghana_postgres.high_availability_enabled ? {
      data_volume_id = module.mtn_ghana_postgres.replica_data_volume_id
      wal_volume_id  = module.mtn_ghana_postgres.replica_wal_volume_id
    } : null
  }
  sensitive = false
}

# ===================================================================================
# EZRA DATABASE OUTPUTS  
# ===================================================================================

output "ezra_database_info" {
  description = "Ezra PostgreSQL database connection information"
  value = {
    client_name   = module.ezra_postgres.client_name
    database_name = module.ezra_postgres.database_name
    database_port = module.ezra_postgres.database_port
    master_endpoint = {
      instance_id = module.ezra_postgres.master_instance_id
      private_ip  = module.ezra_postgres.master_private_ip
      dns_name    = module.ezra_postgres.master_dns_name
      endpoint    = module.ezra_postgres.master_endpoint
    }
    replica_endpoint = module.ezra_postgres.high_availability_enabled ? {
      instance_id = module.ezra_postgres.replica_instance_id
      private_ip  = module.ezra_postgres.replica_private_ip
      dns_name    = module.ezra_postgres.replica_dns_name
      endpoint    = module.ezra_postgres.replica_endpoint
    } : null
    security_group_id = module.ezra_postgres.security_group_id
    high_availability = module.ezra_postgres.high_availability_enabled
  }
}

output "ezra_storage_info" {
  description = "Ezra database storage information"
  value = {
    master_volumes = {
      data_volume_id   = module.ezra_postgres.master_data_volume_id
      wal_volume_id    = module.ezra_postgres.master_wal_volume_id
      backup_volume_id = module.ezra_postgres.master_backup_volume_id
    }
    replica_volumes = module.ezra_postgres.high_availability_enabled ? {
      data_volume_id = module.ezra_postgres.replica_data_volume_id
      wal_volume_id  = module.ezra_postgres.replica_wal_volume_id
    } : null
  }
  sensitive = false
}

# ===================================================================================
# LAYER SUMMARY OUTPUTS
# ===================================================================================

output "database_layer_summary" {
  description = "Summary of all databases deployed in this layer"
  value = {
    layer_name  = "04-database-layer"
    region      = var.aws_region
    environment = "production"
    clients = {
      mtn_ghana = {
        master_ip     = module.mtn_ghana_postgres.master_private_ip
        replica_ip    = module.mtn_ghana_postgres.high_availability_enabled ? module.mtn_ghana_postgres.replica_private_ip : null
        database_name = module.mtn_ghana_postgres.database_name
        port          = module.mtn_ghana_postgres.database_port
      }
      ezra = {
        master_ip     = module.ezra_postgres.master_private_ip
        replica_ip    = module.ezra_postgres.high_availability_enabled ? module.ezra_postgres.replica_private_ip : null
        database_name = module.ezra_postgres.database_name
        port          = module.ezra_postgres.database_port
      }
    }
    total_instances = (
      2 + # MTN Ghana (master + replica)
      2   # Ezra (master + replica)
    )
  }
}

# ===================================================================================
# SENSITIVE OUTPUTS (Only for reference, not displayed)
# ===================================================================================

output "database_credentials_notice" {
  description = "Important notice about database credentials"
  value       = <<-EOT
    🔐 DATABASE CREDENTIALS SECURITY NOTICE
    
    ⚠️  Database passwords are stored as sensitive variables and are NOT exposed in outputs
    ⚠️  Passwords are used internally by terraform but not displayed in state or logs
    ⚠️  To access databases, use the provided connection information with secure credential management
    
    📋 Connection Information:
    - MTN Ghana Master: ${module.mtn_ghana_postgres.master_private_ip}:${module.mtn_ghana_postgres.database_port}
    - MTN Ghana Replica: ${module.mtn_ghana_postgres.high_availability_enabled ? module.mtn_ghana_postgres.replica_private_ip : "N/A"}:${module.mtn_ghana_postgres.database_port}
    - Ezra Master: ${module.ezra_postgres.master_private_ip}:${module.ezra_postgres.database_port}
    - Ezra Replica: ${module.ezra_postgres.high_availability_enabled ? module.ezra_postgres.replica_private_ip : "N/A"}:${module.ezra_postgres.database_port}
    
    🔒 Access credentials through secure AWS Systems Manager Parameter Store or Secrets Manager
  EOT
}
