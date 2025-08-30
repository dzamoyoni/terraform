# MTN Ghana Client Configuration - Production Environment
# Complete client infrastructure specification

mtn_ghana_config = {
  enabled = true
  
  # Client Information
  full_name       = "MTN Ghana"
  business_unit   = "telecommunications"
  cost_center     = "mtn-ghana-production"
  owner_team      = "mtn-ghana-database-team"
  data_class      = "restricted"
  
  # Database Configuration
  database = {
    enabled                = true
    instance_type          = "r5.large"
    port                   = 5433  # Custom PostgreSQL port
    root_volume_size       = 30
    root_volume_type       = "gp3"
    root_volume_encrypted  = false  # Match existing to prevent replacement
    root_volume_iops      = null
    root_volume_throughput = null
    project_name          = "mtn-ghana-prod"
    maintenance_window    = "sun:01:00-sun:02:00"
    subnet_index          = 1  # private_subnets[1] for AZ isolation
    criticality_level     = "critical"
    
    # Security settings
    security = {
      disable_api_termination = true
      disable_api_stop       = false
      enable_monitoring      = false  # Match existing configuration
      shutdown_behavior      = "stop"
    }
    
    # Extra volumes for database storage
    extra_volumes = [
      {
        device_name = "/dev/sdf"
        size        = 50
        type        = "io2"
        encrypted   = true
        iops        = 10000
        throughput  = null
      }
    ]
  }
  
  # Application Servers (Currently none for MTN Ghana)
  applications = {}
  
  # Custom Network Ports
  custom_ports = [
    {
      port        = 5433
      protocol    = "tcp"
      cidr_blocks = ["172.20.0.0/16"]
      description = "PostgreSQL custom port for MTN Ghana"
    }
  ]
  
  # Monitoring Configuration
  monitoring = {
    enabled                = true
    cloudwatch_detailed    = true
    custom_metrics        = false
    alerting_email        = "dennis.juma@ezra.world"
  }
  
  # Backup Configuration
  backup = {
    enabled            = true
    schedule          = "continuous"
    time              = "02:00"  # 2 AM UTC backup time
    retention_days    = 30
    cross_region_copy = true
  }
}

# Environment-specific overrides for production
mtn_ghana_production_overrides = {
  # Enhanced monitoring for production
  enable_enhanced_monitoring = true
  
  # Production-specific backup settings
  backup_cross_region_destination = "af-south-1"
  
  # Compliance requirements
  enable_audit_logging = true
  
  # Performance optimization
  database_performance_insights = true
  
  # Security enhancements
  enable_encryption_in_transit = true
}
