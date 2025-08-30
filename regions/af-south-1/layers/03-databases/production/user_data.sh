#!/bin/bash
# CPTWN Database Instance Initialization Script for Debian 12
# Client: ${client_name}
# Cluster: ${cluster_name}

set -e

# Update system
apt-get update -y
apt-get upgrade -y

# Install essential packages for Debian 12
apt-get install -y \
    curl \
    wget \
    unzip \
    awscli \
    htop \
    iotop \
    jq \
    tree \
    vim \
    postgresql-client-15 \
    default-mysql-client \
    redis-tools \
    ca-certificates \
    gnupg

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb
rm amazon-cloudwatch-agent.deb

# Configure SSM agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Create database directory structure
mkdir -p /opt/database/{data,logs,backups}
chown -R admin:admin /opt/database

# Set up EBS volume mounting script (if additional volumes are attached)
cat > /opt/database/mount-ebs.sh << 'EOF'
#!/bin/bash
# Mount additional EBS volumes for ${client_name}

# Mount primary data volume (sdf)
if lsblk | grep -q sdf; then
    echo "Primary data EBS volume detected, setting up..."
    
    # Format if not already formatted
    if ! blkid /dev/sdf; then
        mkfs.ext4 /dev/sdf
    fi
    
    # Mount the volume
    mkdir -p /opt/database/data
    mount /dev/sdf /opt/database/data
    
    # Add to fstab for persistent mounting
    echo '/dev/sdf /opt/database/data ext4 defaults,nofail 0 2' >> /etc/fstab
    
    # Set permissions
    chown -R admin:admin /opt/database/data
    chmod 755 /opt/database/data
    
    echo "Primary data EBS volume mounted successfully at /opt/database/data"
else
    echo "No primary data EBS volume found"
fi

# Mount secondary logs volume (sdg) - COMMENTED OUT FOR INITIAL DEPLOYMENT
# if lsblk | grep -q sdg; then
#     echo "Secondary logs EBS volume detected, setting up..."
#     
#     # Format if not already formatted
#     if ! blkid /dev/sdg; then
#         mkfs.ext4 /dev/sdg
#     fi
#     
#     # Mount the volume
#     mkdir -p /opt/database/logs
#     mount /dev/sdg /opt/database/logs
#     
#     # Add to fstab for persistent mounting
#     echo '/dev/sdg /opt/database/logs ext4 defaults,nofail 0 2' >> /etc/fstab
#     
#     # Set permissions
#     chown -R admin:admin /opt/database/logs
#     chmod 755 /opt/database/logs
#     
#     echo "Secondary logs EBS volume mounted successfully at /opt/database/logs"
# else
#     echo "No secondary logs EBS volume found"
# fi
EOF

chmod +x /opt/database/mount-ebs.sh

# Create database environment file
cat > /opt/database/.env << EOF
# CPTWN Database Environment Configuration
CLIENT_NAME=${client_name}
CLUSTER_NAME=${cluster_name}
REGION=af-south-1
ENVIRONMENT=production
DATABASE_PATH=/opt/database/data
BACKUP_PATH=/opt/database/backups
LOG_PATH=/opt/database/logs
EOF

# Create database maintenance script
cat > /opt/database/maintenance.sh << 'EOF'
#!/bin/bash
# CPTWN Database Maintenance Script
source /opt/database/.env

echo "$(date): Starting database maintenance for $CLIENT_NAME"

# Log rotation
find $LOG_PATH -name "*.log" -mtime +7 -delete 2>/dev/null || true

# Cleanup old backups (keep last 30 days)
find $BACKUP_PATH -name "*.sql*" -mtime +30 -delete 2>/dev/null || true

echo "$(date): Database maintenance completed for $CLIENT_NAME"
EOF

chmod +x /opt/database/maintenance.sh

# Set up cron job for maintenance
echo "0 2 * * * /opt/database/maintenance.sh >> /opt/database/logs/maintenance.log 2>&1" | crontab -

# Log initialization completion
echo "$(date): CPTWN Database instance initialized for ${client_name} on ${cluster_name}" >> /var/log/cptwn-init.log

# Signal completion
echo "CPTWN Database initialization completed successfully" > /opt/database/init-complete.flag
