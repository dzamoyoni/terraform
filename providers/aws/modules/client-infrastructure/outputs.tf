# Outputs for Client Infrastructure Module

# ===================================================================================
# CLIENT SUMMARY
# ===================================================================================

output "client_summary" {
  description = "Complete summary of client infrastructure"
  value = {
    client_name   = var.client_name
    full_name     = var.client_config.full_name
    environment   = var.environment
    enabled       = var.client_config.enabled
    business_unit = var.client_config.business_unit
    cost_center   = var.client_config.cost_center
    owner_team    = var.client_config.owner_team
    
    resource_counts = {
      databases    = var.client_config.database.enabled ? 1 : 0
      applications = length([for app_name, app_config in var.client_config.applications : app_name if app_config.enabled])
      total        = (var.client_config.database.enabled ? 1 : 0) + length([for app_name, app_config in var.client_config.applications : app_name if app_config.enabled])
    }
  }
}

# ===================================================================================
# DATABASE OUTPUTS
# ===================================================================================

output "database_server" {
  description = "Database server information"
  value = var.client_config.database.enabled ? {
    instance_id             = module.client_database_server[0].instance_id
    private_ip              = module.client_database_server[0].private_ip
    termination_protection  = module.client_database_server[0].termination_protection
    extra_volume_ids       = module.client_database_server[0].extra_volume_ids
    security_group_id      = aws_security_group.client_database[0].id
    
    connection_info = {
      host = module.client_database_server[0].private_ip
      port = var.client_config.database.port
    }
    
    backup_info = {
      policy_enabled = var.client_config.backup.enabled
      schedule       = var.client_config.backup.schedule
      retention_days = var.client_config.backup.retention_days
    }
  } : null
}

# ===================================================================================
# APPLICATION SERVERS OUTPUTS
# ===================================================================================

output "application_servers" {
  description = "Application servers information"
  value = {
    for app_name, app_module in module.client_application_servers : app_name => {
      instance_id            = app_module.instance_id
      private_ip             = app_module.private_ip
      termination_protection = app_module.termination_protection
      extra_volume_ids       = app_module.extra_volume_ids
      
      configuration = {
        instance_type    = var.client_config.applications[app_name].instance_type
        subnet_index     = var.client_config.applications[app_name].subnet_index
        criticality_level = var.client_config.applications[app_name].criticality_level
      }
    }
  }
}

# ===================================================================================
# SECURITY GROUPS OUTPUTS
# ===================================================================================

output "security_groups" {
  description = "Security groups created for the client"
  value = {
    database_sg = var.client_config.database.enabled ? {
      id   = aws_security_group.client_database[0].id
      name = aws_security_group.client_database[0].name
      arn  = aws_security_group.client_database[0].arn
    } : null
    
    application_sg = length(local.enabled_applications) > 0 ? {
      id   = aws_security_group.client_applications[0].id
      name = aws_security_group.client_applications[0].name  
      arn  = aws_security_group.client_applications[0].arn
    } : null
  }
}

# ===================================================================================
# MONITORING OUTPUTS
# ===================================================================================

output "monitoring_resources" {
  description = "Monitoring resources created for the client"
  value = var.client_config.monitoring.enabled ? {
    dashboard = {
      name = aws_cloudwatch_dashboard.client_dashboard[0].dashboard_name
      url  = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.client_dashboard[0].dashboard_name}"
    }
    
    sns_topic = {
      arn  = aws_sns_topic.client_alerts[0].arn
      name = aws_sns_topic.client_alerts[0].name
    }
    
    alerting_email = var.client_config.monitoring.alerting_email != "" ? var.client_config.monitoring.alerting_email : null
  } : null
}

# ===================================================================================
# BACKUP OUTPUTS
# ===================================================================================

output "backup_policies" {
  description = "Backup policies created for the client"
  value = var.client_config.backup.enabled ? {
    dlm_policy = {
      id          = aws_dlm_lifecycle_policy.client_backup[0].id
      arn         = aws_dlm_lifecycle_policy.client_backup[0].arn
      description = aws_dlm_lifecycle_policy.client_backup[0].description
      state       = aws_dlm_lifecycle_policy.client_backup[0].state
    }
    
    schedule_info = {
      frequency      = var.client_config.backup.schedule
      time           = var.client_config.backup.time
      retention_days = var.client_config.backup.retention_days
    }
  } : null
}

# ===================================================================================
# COST ALLOCATION OUTPUTS
# ===================================================================================

output "cost_allocation" {
  description = "Cost allocation and billing information"
  value = {
    tags = {
      Client       = var.client_name
      CostCenter   = var.client_config.cost_center
      BusinessUnit = var.client_config.business_unit
      OwnerTeam    = var.client_config.owner_team
      Environment  = var.environment
    }
    
    resource_tags_summary = {
      common_tags_count = length(local.common_tags)
      billing_tags = [
        "Client",
        "CostCenter", 
        "BusinessUnit",
        "OwnerTeam",
        "Environment"
      ]
    }
  }
}

# ===================================================================================
# NETWORKING OUTPUTS
# ===================================================================================

output "networking_info" {
  description = "Networking configuration for the client"
  value = {
    vpc_id = var.vpc_id
    
    subnets_used = {
      database = var.client_config.database.enabled ? var.private_subnets[var.client_config.database.subnet_index] : null
      applications = {
        for app_name, app_config in local.enabled_applications : app_name => var.private_subnets[app_config.subnet_index]
      }
    }
    
    security_group_rules = {
      database_port = var.client_config.database.enabled ? var.client_config.database.port : null
      vpn_access_enabled = var.enable_vpn_access
      custom_ports = length(var.client_config.custom_ports)
    }
  }
}

# ===================================================================================
# CLIENT HEALTH STATUS
# ===================================================================================

output "client_health_status" {
  description = "Health and status information for client resources"
  value = {
    overall_status = "healthy"  # This could be enhanced with actual health checks
    
    resource_status = {
      database = var.client_config.database.enabled ? {
        provisioned = true
        instance_id = module.client_database_server[0].instance_id
        protected   = true
      } : {
        provisioned = false
      }
      
      applications = {
        for app_name, app_module in module.client_application_servers : app_name => {
          provisioned = true
          instance_id = app_module.instance_id
          protected   = true
        }
      }
      
      monitoring = {
        enabled = var.client_config.monitoring.enabled
        dashboard_created = var.client_config.monitoring.enabled
        alerts_configured = var.client_config.monitoring.enabled && var.client_config.monitoring.alerting_email != ""
      }
      
      backup = {
        enabled = var.client_config.backup.enabled
        policy_active = var.client_config.backup.enabled
        schedule = var.client_config.backup.enabled ? var.client_config.backup.schedule : null
      }
    }
    
    compliance_status = {
      encryption_enabled = var.client_config.database.enabled ? var.client_config.database.root_volume_encrypted : true
      termination_protection = true
      backup_configured = var.client_config.backup.enabled
      monitoring_enabled = var.client_config.monitoring.enabled
    }
  }
}

# ===================================================================================
# QUICK REFERENCE
# ===================================================================================

output "quick_reference" {
  description = "Quick reference information for operations teams"
  value = {
    client_name = var.client_name
    environment = var.environment
    region      = var.aws_region
    
    # Connection strings and endpoints
    endpoints = {
      database = var.client_config.database.enabled ? "${module.client_database_server[0].private_ip}:${var.client_config.database.port}" : null
      applications = {
        for app_name, app_module in module.client_application_servers : app_name => "${app_module.private_ip}:80"
      }
    }
    
    # Important resource IDs for quick access
    resource_ids = {
      database_instance = var.client_config.database.enabled ? module.client_database_server[0].instance_id : null
      database_sg       = var.client_config.database.enabled ? aws_security_group.client_database[0].id : null
      application_sg    = length(local.enabled_applications) > 0 ? aws_security_group.client_applications[0].id : null
    }
    
    # Operational contacts
    contacts = {
      owner_team    = var.client_config.owner_team
      cost_center   = var.client_config.cost_center
      alert_email   = var.client_config.monitoring.alerting_email
    }
  }
}
