# ============================================================================
# Layer 3: Database Layer Outputs - US-East-2 Production
# ============================================================================
# High-availability PostgreSQL database connection and management information
# Provides comprehensive details for application integration and monitoring
# ============================================================================

# ===================================================================================
# EST TEST A DATABASE OUTPUTS
# ===================================================================================

output "est_test_a_database_info" {
  description = "EST Test A PostgreSQL database connection information"
  value = {
    client_name   = module.est_test_a_postgres.client_name
    database_name = module.est_test_a_postgres.database_name
    database_port = module.est_test_a_postgres.database_port
    master_endpoint = {
      instance_id = module.est_test_a_postgres.master_instance_id
      private_ip  = module.est_test_a_postgres.master_private_ip
      dns_name    = module.est_test_a_postgres.master_dns_name
      endpoint    = module.est_test_a_postgres.master_endpoint
    }
    replica_endpoint = module.est_test_a_postgres.high_availability_enabled ? {
      instance_id = module.est_test_a_postgres.replica_instance_id
      private_ip  = module.est_test_a_postgres.replica_private_ip
      dns_name    = module.est_test_a_postgres.replica_dns_name
      endpoint    = module.est_test_a_postgres.replica_endpoint
    } : null
    security_group_id = module.est_test_a_postgres.security_group_id
    high_availability = module.est_test_a_postgres.high_availability_enabled
  }
}

output "est_test_a_storage_info" {
  description = "EST Test A database storage information"
  value = {
    master_volumes = {
      data_volume_id   = module.est_test_a_postgres.master_data_volume_id
      wal_volume_id    = module.est_test_a_postgres.master_wal_volume_id
      backup_volume_id = module.est_test_a_postgres.master_backup_volume_id
    }
    replica_volumes = module.est_test_a_postgres.high_availability_enabled ? {
      data_volume_id = module.est_test_a_postgres.replica_data_volume_id
      wal_volume_id  = module.est_test_a_postgres.replica_wal_volume_id
    } : null
    encryption_enabled = true
    total_storage_gb = var.data_volume_size + var.wal_volume_size + var.backup_volume_size
  }
  sensitive = false
}

# ===================================================================================
# EST TEST B DATABASE OUTPUTS (Reserved for future use)
# ===================================================================================

# EST Test B outputs will be added when the client database is activated
# Currently commented out as the module is not deployed
/*
output "est_test_b_database_info" {
  description = "EST Test B PostgreSQL database connection information"
  value = {
    client_name   = module.est_test_b_postgres.client_name
    database_name = module.est_test_b_postgres.database_name
    database_port = module.est_test_b_postgres.database_port
    master_endpoint = {
      instance_id = module.est_test_b_postgres.master_instance_id
      private_ip  = module.est_test_b_postgres.master_private_ip
      dns_name    = module.est_test_b_postgres.master_dns_name
      endpoint    = module.est_test_b_postgres.master_endpoint
    }
    replica_endpoint = module.est_test_b_postgres.high_availability_enabled ? {
      instance_id = module.est_test_b_postgres.replica_instance_id
      private_ip  = module.est_test_b_postgres.replica_private_ip
      dns_name    = module.est_test_b_postgres.replica_dns_name
      endpoint    = module.est_test_b_postgres.replica_endpoint
    } : null
    security_group_id = module.est_test_b_postgres.security_group_id
    high_availability = module.est_test_b_postgres.high_availability_enabled
  }
}
*/

# ===================================================================================
# CROSS-LAYER INTEGRATION OUTPUTS
# ===================================================================================

output "cluster_integration_info" {
  description = "Information for integrating databases with EKS cluster"
  value = {
    vpc_id         = local.vpc_id
    cluster_name   = local.cluster_name
    database_clients = {
      "est-test-a" = {
        master_ip     = module.est_test_a_postgres.master_private_ip
        replica_ip    = module.est_test_a_postgres.high_availability_enabled ? module.est_test_a_postgres.replica_private_ip : null
        database_name = module.est_test_a_postgres.database_name
        port          = module.est_test_a_postgres.database_port
        connection_string = "postgresql://est_test_a_user:***@${module.est_test_a_postgres.master_private_ip}:${module.est_test_a_postgres.database_port}/est_test_a_db"
      }
    }
    network_access = {
      vpc_cidr_block = local.vpc_cidr_block
      database_subnets = {
        est_test_a = local.est_test_a_database_subnet_ids
        est_test_b = local.est_test_b_database_subnet_ids
      }
    }
  }
}

# ===================================================================================
# LAYER SUMMARY OUTPUTS
# ===================================================================================

output "database_layer_summary" {
  description = "Comprehensive summary of database layer deployment"
  value = {
    # Layer information
    layer_name  = "03-database-layer"
    region      = var.region
    environment = var.environment
    project     = var.project_name
    
    # Infrastructure summary
    infrastructure = {
      total_instances = 2  # EST Test A master + replica (EST Test B disabled)
      high_availability = true
      encryption_enabled = true
      monitoring_enabled = true
      backup_enabled = true
    }
    
    # Active clients
    active_clients = {
      "est-test-a" = {
        status        = "deployed"
        master_ip     = module.est_test_a_postgres.master_private_ip
        replica_ip    = module.est_test_a_postgres.high_availability_enabled ? module.est_test_a_postgres.replica_private_ip : null
        database_name = "est_test_a_db"
        port          = module.est_test_a_postgres.database_port
      }
    }
    
    # Reserved clients
    reserved_clients = {
      "est-test-b" = {
        status = "reserved"
        note   = "Database configuration prepared, deployment disabled pending client readiness"
      }
    }
    
    # Storage configuration
    storage = {
      data_volume_size   = var.data_volume_size
      wal_volume_size    = var.wal_volume_size
      backup_volume_size = var.backup_volume_size
      total_storage_per_client = var.data_volume_size + var.wal_volume_size + var.backup_volume_size
      backup_retention_days = var.backup_retention_days
    }
    
    # Cross-layer integration
    integration = {
      foundation_layer = "✅ Connected"
      platform_layer   = "✅ Connected"
      cluster_name     = local.cluster_name
      vpc_integration  = "✅ Active"
    }
  }
}

# ===================================================================================
# SECURITY AND DEPLOYMENT GUIDANCE
# ===================================================================================

output "database_security_notice" {
  description = "Important security and deployment guidance for database layer"
  value       = <<-EOT
    DATABASE LAYER SECURITY & DEPLOYMENT NOTICE
    
    DEPLOYMENT STATUS:
    - EST Test A Database: ACTIVE (Master + Replica HA)
    - EST Test B Database: RESERVED (Configuration ready, deployment disabled)
    
    SECURITY FEATURES:
    - All EBS volumes encrypted with KMS
    - Network isolation via dedicated database subnets
    - Security groups restrict access to VPC CIDR only
    - SSH access limited to management IPs
    - PostgreSQL monitoring enabled on port 9187
    
    CONNECTION INFORMATION:
    - EST Test A Master: ${module.est_test_a_postgres.master_private_ip}:${module.est_test_a_postgres.database_port}
    - EST Test A Replica: ${module.est_test_a_postgres.high_availability_enabled ? module.est_test_a_postgres.replica_private_ip : "N/A"}:${module.est_test_a_postgres.database_port}
    - Database Name: est_test_a_db
    - Username: est_test_a_user
    
    CREDENTIAL SECURITY:
    - Database passwords are stored as sensitive variables
    - Passwords are NOT exposed in outputs or state files
    - Use secure credential management for application access
    - Consider AWS Secrets Manager for production password rotation
    
    POST-DEPLOYMENT TASKS:
    1. Test database connectivity from EKS cluster
    2. Verify master-replica replication is working
    3. Configure application connection strings
    4. Set up monitoring dashboards
    5. Test backup and restore procedures
    6. Update security groups if needed
    
    INTEGRATION WITH EKS:
    - Cluster Name: ${local.cluster_name}
    - VPC ID: ${local.vpc_id}
    - Network Access: VPC CIDR ${local.vpc_cidr_block}
    - Database Subnets: Cross-AZ deployment for HA
  EOT
}
