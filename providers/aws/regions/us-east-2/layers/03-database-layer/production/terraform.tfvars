# ============================================================================
# Database Layer - Production Configuration
# ============================================================================
# High-Availability PostgreSQL database configuration for production environment
# Contains sensitive information - DO NOT commit passwords to version control
# ============================================================================

# ===================================================================================
# CORE PROJECT CONFIGURATION
# ===================================================================================

project_name = "ohio-01-eks"
environment  = "production"
region      = "us-east-2"

# ===================================================================================
# REMOTE STATE CONFIGURATION
# ===================================================================================

terraform_state_bucket = "ohio-01-terraform-state-production"
terraform_state_region = "us-east-2"

# ===================================================================================
# INFRASTRUCTURE CONFIGURATION
# ===================================================================================

# PostgreSQL AMI (pre-configured with PostgreSQL)
postgres_ami_id = "ami-0bb7d855677353076"

# SSH Key for instance access
key_name = "ohio-01-keypair"

# Instance types for production (memory-optimized for database workloads)
master_instance_type  = "r5.large"   # 2 vCPUs, 16 GB RAM
replica_instance_type = "r5.large"   # 2 vCPUs, 16 GB RAM

# ===================================================================================
# SECURITY CONFIGURATION
# ===================================================================================

# Management access (SSH, monitoring) - restrict to your IPs
management_cidr_blocks = [
  "102.217.4.85/32",   # Your primary management IP
  "165.90.14.138/32",  # Backup management IP
  "178.162.141.130/32", # Additional management IP
  "41.72.206.78/32"    # Secondary management IP
]

# ===================================================================================
# STORAGE CONFIGURATION - Production-Grade Volumes
# ===================================================================================

# PostgreSQL data volume (main database files)
data_volume_size = 20 # GB

# Write-Ahead Log volume (transaction logs)
wal_volume_size = 20    # GB

# Backup volume (database backups)
backup_volume_size = 20 # GB

# Backup retention
backup_retention_days = 30 # days

# ===================================================================================
# CLIENT DATABASE CREDENTIALS (SENSITIVE - SET THESE VALUES)
# ===================================================================================

# EST Test A Database Passwords
# Production-grade secure passwords
est_test_a_db_password          = "EstTestA_DB_P@ssw0rd_2025_Secure!"
est_test_a_replication_password = "EstTestA_Repl_P@ssw0rd_2025_Secure!"

# EST Test B Database Passwords (Reserved for future use)
# These will be activated when EST Test B client is ready
est_test_b_db_password          = "TempPassword123!"
est_test_b_replication_password = "TempReplPassword123!"

# ===================================================================================
# DEPLOYMENT NOTES
# ===================================================================================
#
# Before deploying:
# 1. Update database passwords with secure values
# 2. Verify management CIDR blocks are correct
# 3. Confirm key_name exists in us-east-2
# 4. Ensure Foundation and Platform layers are deployed
#
# Post-deployment:
# 1. Test database connectivity from EKS cluster
# 2. Verify master-replica replication is working
# 3. Configure monitoring and alerting
# 4. Test backup and restore procedures
# 5. Update application connection strings
#
# ============================================================================