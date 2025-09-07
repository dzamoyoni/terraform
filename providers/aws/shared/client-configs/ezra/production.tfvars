# Ezra Client Configuration - Production Environment
# Complete client infrastructure specification

ezra_config = {
  enabled = true
  
  # Client Information
  full_name       = "Ezra"
  business_unit   = "fintech"
  cost_center     = "ezra-production"
  owner_team      = "ezra-team"
  data_class      = "restricted"
  
  # Database Configuration (Note: ezra-prod-app-01 is actually a database server)
  database = {
    enabled                = true
    instance_type          = "r5.large"
    port                   = 5433  # Custom PostgreSQL port
    root_volume_size       = 30
    root_volume_type       = "gp3"
    root_volume_encrypted  = true   # Match existing configuration
    root_volume_iops      = 3000   # Match existing IOPS
    root_volume_throughput = 125    # Match existing throughput
    project_name          = "ezra-prod"
    maintenance_window    = "sun:04:00-sun:05:00"
    subnet_index          = 0  # private_subnets[0] to match existing
    criticality_level     = "critical"
    
    # Security settings
    security = {
      disable_api_termination = true
      disable_api_stop       = false
      enable_monitoring      = true   # Match existing monitoring
      shutdown_behavior      = "stop"
    }
    
    # Extra volumes for database storage
    extra_volumes = [
      {
        device_name = "/dev/sdf"
        size        = 20      # Match existing volume size
        type        = "gp3"   # Match existing volume type
        encrypted   = true
        iops        = 3000    # Match existing IOPS
        throughput  = 125     # Match existing throughput
      }
    ]
  }
  
  # Application Servers (Currently none - ezra only has database)
  applications = {}
  
  # Custom Network Ports
  custom_ports = [
    {
      port        = 5433
      protocol    = "tcp"
      cidr_blocks = ["172.20.0.0/16"]
      description = "PostgreSQL custom port for Ezra"
    }
  ]
  
  # Monitoring Configuration
  monitoring = {
    enabled                = true
    cloudwatch_detailed    = true
    custom_metrics        = true   # Enable custom metrics for fintech
    alerting_email        = "dennis.juma@ezra.world"
  }
  
  # Backup Configuration
  backup = {
    enabled            = true
    schedule          = "hourly"   # More frequent backups for fintech
    time              = "01:00"    # 1 AM UTC backup time
    retention_days    = 45         # Longer retention for compliance
    cross_region_copy = true
  }
}

# Environment-specific overrides for production
ezra_production_overrides = {
  # Enhanced monitoring for fintech compliance
  enable_enhanced_monitoring = true
  enable_performance_insights = true
  
  # Production-specific backup settings
  backup_cross_region_destination = "eu-west-1"  # Different region for geographic diversity
  
  # Compliance requirements for fintech
  enable_audit_logging = true
  enable_transaction_logging = true
  
  # Security enhancements for financial data
  enable_encryption_in_transit = true
  enable_network_isolation = true
  
  # Performance optimization for high-frequency transactions
  enable_connection_pooling = true
  optimize_for_oltp = true
}
