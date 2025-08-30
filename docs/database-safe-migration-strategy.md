# Database-Safe Migration Strategy - Zero Data Loss Approach

## ⚠️ **CRITICAL: Database Protection Protocol**

This document outlines the **ZERO DATA LOSS** migration strategy for database EC2 instances and their attached volumes during the scalable architecture migration.

## Current Database Infrastructure

### MTN Ghana Database Server
- **Instance ID**: `i-0cc10f5d328cfa839`
- **Instance Type**: `r5.large`
- **Availability Zone**: `us-east-1b`
- **Private IP**: `172.20.2.33`
- **Extra Volume**: `vol-01f92db75a625744e` (50GB, encrypted)
- **Termination Protection**: ✅ Enabled
- **IAM Profile**: `mtn-ghana-prod-database-ssm-profile`

### Ezra Database Server
- **Instance ID**: `i-0ff321d8d4f1b35e5`
- **Instance Type**: `r5.large`
- **Availability Zone**: `us-east-1a`
- **Private IP**: `172.20.1.153`
- **Extra Volume**: attached and configured
- **Termination Protection**: ✅ Enabled
- **IAM Profile**: `ezra-prod-app-01-ssm-profile`

## 🛡️ **Database Protection Principles**

1. **NO RESOURCE RECREATION**: Database instances will NEVER be destroyed and recreated
2. **STATE IMPORT ONLY**: We only import existing resources to new state files
3. **VOLUME PRESERVATION**: All EBS volumes remain attached and unchanged
4. **BACKUP FIRST**: Create snapshots before any state operations
5. **ROLLBACK READY**: Complete rollback procedures for every step

## 🔒 **Pre-Migration Database Safety Checklist**

### Phase 1: Pre-Migration Backups
```bash
#!/bin/bash
# Create comprehensive backups before migration

# 1. Create EBS snapshots
aws ec2 create-snapshot \
    --volume-id vol-01f92db75a625744e \
    --description "MTN Ghana DB Pre-Migration Backup $(date)" \
    --tag-specifications 'ResourceType=snapshot,Tags=[{Key=Purpose,Value=PreMigrationBackup},{Key=Client,Value=mtn-ghana}]'

aws ec2 create-snapshot \
    --volume-id vol-EZRA_VOLUME_ID \
    --description "Ezra DB Pre-Migration Backup $(date)" \
    --tag-specifications 'ResourceType=snapshot,Tags=[{Key=Purpose,Value=PreMigrationBackup},{Key=Client,Value=ezra}]'

# 2. Create AMI of database instances (for complete system backup)
aws ec2 create-image \
    --instance-id i-0cc10f5d328cfa839 \
    --name "mtn-ghana-db-pre-migration-$(date +%Y%m%d)" \
    --description "MTN Ghana DB complete system backup before migration"

aws ec2 create-image \
    --instance-id i-0ff321d8d4f1b35e5 \
    --name "ezra-db-pre-migration-$(date +%Y%m%d)" \
    --description "Ezra DB complete system backup before migration"

# 3. Export current terraform state
terraform state pull > database-state-backup-$(date +%Y%m%d_%H%M%S).json
```

### Phase 2: Database Service Verification
```bash
#!/bin/bash
# Verify database services before migration

# Connect to each database and verify data integrity
ssh -i ~/.ssh/terraform-key ubuntu@172.20.2.33 "sudo systemctl status postgresql"
ssh -i ~/.ssh/terraform-key ubuntu@172.20.1.153 "sudo systemctl status postgresql"

# Create database dumps (additional safety)
ssh -i ~/.ssh/terraform-key ubuntu@172.20.2.33 "sudo -u postgres pg_dumpall > /var/backups/pre-migration-dump-$(date +%Y%m%d).sql"
ssh -i ~/.ssh/terraform-key ubuntu@172.20.1.153 "sudo -u postgres pg_dumpall > /var/backups/pre-migration-dump-$(date +%Y%m%d).sql"
```

## 🔄 **Safe Database Migration Approach**

### Method: **STATE IMPORT ONLY** (No Resource Changes)

Instead of recreating database resources, we will:

1. **Create new layer configurations** that match existing resources EXACTLY
2. **Import existing resources** to new state files without any changes
3. **Verify no changes needed** with `terraform plan`
4. **Keep original state** as backup until verification complete

### Database Layer Configuration Strategy

The new database layer will be configured to **match existing resources exactly**:

```hcl
# regions/us-east-1/layers/03-databases/production/main.tf

# MTN Ghana Database - EXACT match to existing
resource "aws_instance" "mtn_ghana_db" {
  # EXACTLY match current instance configuration
  ami           = "ami-0779caf41f9ba54f0"
  instance_type = "r5.large"
  key_name      = "terraform-key"
  
  # CRITICAL: Match exact subnet and security groups
  subnet_id              = "subnet-EXACT_CURRENT_SUBNET"
  vpc_security_group_ids = ["sg-067bc5c25980da2cc"] # Existing database SG
  
  # CRITICAL: Disable termination protection during import, re-enable after
  disable_api_termination = true
  
  # EXACT tag matching
  tags = {
    Name              = "mtn-ghana-prod-database"
    Client            = "mtn-ghana"
    Critical          = "true"
    CriticalityLevel  = "critical"
    BackupRequired    = "true"
    # ... exact tag matching
  }
}

resource "aws_ebs_volume" "mtn_ghana_extra" {
  # EXACT match to existing volume
  availability_zone = "us-east-1b"
  size             = 50
  type             = "gp3"
  encrypted        = true
  iops             = 10000
  
  tags = {
    # EXACT tag matching
  }
}

resource "aws_volume_attachment" "mtn_ghana_extra" {
  device_name = "/dev/sdf"  # EXACT match
  volume_id   = aws_ebs_volume.mtn_ghana_extra.id
  instance_id = aws_instance.mtn_ghana_db.id
}
```

### Import Commands (SAFE)

```bash
# Import existing resources to new state (NO CHANGES to actual resources)
cd regions/us-east-1/layers/03-databases/production

# Initialize new state
terraform init -backend-config="../../../../../shared/backend-configs/production.hcl"

# Import MTN Ghana database resources
terraform import aws_instance.mtn_ghana_db i-0cc10f5d328cfa839
terraform import aws_ebs_volume.mtn_ghana_extra vol-01f92db75a625744e
terraform import aws_volume_attachment.mtn_ghana_extra /dev/sdf:vol-01f92db75a625744e:i-0cc10f5d328cfa839

# Import Ezra database resources  
terraform import aws_instance.ezra_db i-0ff321d8d4f1b35e5
terraform import aws_ebs_volume.ezra_extra vol-EZRA_VOLUME_ID
terraform import aws_volume_attachment.ezra_extra /dev/sdf:vol-EZRA_VOLUME_ID:i-0ff321d8d4f1b35e5

# CRITICAL: Verify no changes needed
terraform plan  # MUST show "No changes" or migration config needs adjustment
```

## 🚨 **Safety Validations**

### Validation 1: No Changes Required
```bash
# After import, terraform plan MUST show no changes
terraform plan -detailed-exitcode
exit_code=$?
if [ $exit_code -eq 0 ]; then
    echo "✅ SUCCESS: No changes required - import successful"
elif [ $exit_code -eq 2 ]; then
    echo "❌ ERROR: Changes detected - configuration mismatch"
    echo "STOP MIGRATION - Review and fix configuration"
    exit 1
fi
```

### Validation 2: Database Connectivity
```bash
# Verify databases remain accessible
ssh -i ~/.ssh/terraform-key ubuntu@172.20.2.33 "sudo systemctl status postgresql"
ssh -i ~/.ssh/terraform-key ubuntu@172.20.1.153 "sudo systemctl status postgresql"

# Test database connections from applications
kubectl exec -it deployment/mtn-ghana-app -- pg_isready -h 172.20.2.33 -p 5432
kubectl exec -it deployment/ezra-app -- pg_isready -h 172.20.1.153 -p 5433
```

### Validation 3: Volume Attachment Verification
```bash
# Verify volumes remain attached
aws ec2 describe-volumes --volume-ids vol-01f92db75a625744e --query 'Volumes[0].Attachments'
aws ec2 describe-volumes --volume-ids vol-EZRA_VOLUME_ID --query 'Volumes[0].Attachments'

# Verify from instance level
ssh -i ~/.ssh/terraform-key ubuntu@172.20.2.33 "lsblk"
ssh -i ~/.ssh/terraform-key ubuntu@172.20.1.153 "lsblk"
```

## 🔄 **Rollback Procedures**

### Immediate Rollback (if issues detected)
```bash
#!/bin/bash
# Emergency rollback procedure

echo "🚨 INITIATING DATABASE MIGRATION ROLLBACK 🚨"

# 1. Switch back to original terraform state
cd regions/us-east-1/clusters/production
terraform state push database-state-backup-TIMESTAMP.json

# 2. Verify original state restored
terraform plan  # Should show no changes

# 3. Verify database accessibility
ssh -i ~/.ssh/terraform-key ubuntu@172.20.2.33 "sudo systemctl status postgresql"
ssh -i ~/.ssh/terraform-key ubuntu@172.20.1.153 "sudo systemctl status postgresql"

echo "✅ Rollback completed - databases should be operational"
```

### Volume Recovery (if needed)
```bash
# If volume issues occur (EMERGENCY ONLY)
# 1. Stop application traffic to databases
# 2. Create new volume from pre-migration snapshot
aws ec2 create-volume \
    --snapshot-id snap-PREMIGRATION_SNAPSHOT \
    --availability-zone us-east-1b \
    --volume-type gp3

# 3. Attach to instance (requires instance stop)
# NOTE: This is emergency recovery only
```

## 📋 **Database Migration Execution Plan**

### Step-by-Step Safe Migration

1. **Pre-Migration (Critical)**
   - [ ] Create EBS snapshots of all database volumes
   - [ ] Create AMI backups of database instances
   - [ ] Create database dumps
   - [ ] Export current terraform state
   - [ ] Verify all backups completed successfully

2. **Configuration Preparation**
   - [ ] Create database layer terraform configuration matching EXACT resource specifications
   - [ ] Double-check all tags, security groups, and network settings
   - [ ] Validate configuration syntax

3. **Safe Import Process**
   - [ ] Initialize new database layer backend
   - [ ] Import database instances (state only, no resource changes)
   - [ ] Import EBS volumes (state only, no resource changes)  
   - [ ] Import volume attachments (state only, no resource changes)
   - [ ] Import IAM resources (state only, no resource changes)

4. **Verification Phase**
   - [ ] Verify `terraform plan` shows NO CHANGES
   - [ ] Test database connectivity from applications
   - [ ] Verify volume attachments intact
   - [ ] Run database health checks
   - [ ] Validate backup policies still active

5. **Final Validation**
   - [ ] Full application testing with databases
   - [ ] Performance monitoring during and after migration
   - [ ] Backup verification (new backups from new layer)
   - [ ] Documentation update

## ✅ **Success Criteria**

- [ ] All database instances operational and unchanged
- [ ] All volumes attached and accessible  
- [ ] Zero data loss confirmed
- [ ] Applications connecting normally
- [ ] Backup policies functioning
- [ ] Performance maintained
- [ ] New terraform state managing resources correctly with NO CHANGES required

## 🚨 **STOP CONDITIONS**

**Immediately STOP migration if:**
- `terraform plan` shows ANY changes to database resources
- Database instances become inaccessible
- Volume attachments are disrupted
- Any data integrity issues detected
- Applications lose database connectivity

**In case of ANY issues**: Execute immediate rollback procedures and investigate before proceeding.

---

## Summary

This database-safe migration strategy ensures **ZERO RISK** to your critical database infrastructure by:

1. **Only importing state** - never recreating resources
2. **Comprehensive backups** before any operations
3. **Exact configuration matching** to prevent changes
4. **Multiple validation steps** at each stage
5. **Complete rollback capability** at any point

The databases will continue running exactly as they are today, with only the terraform state management changing to the new layered architecture.
