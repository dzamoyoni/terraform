# Terraform Scripts Directory

This directory contains scripts and utilities for managing the enhanced multi-tenant Terraform architecture. These tools automate deployment, client management, and maintenance tasks for the infrastructure.

## Directory Structure

```
scripts/
├── deployment/                 # Deployment and migration scripts
│   ├── migrate-to-enhanced-architecture.sh
│   └── deploy-environment.sh   # (planned)
├── client-management/          # Client lifecycle management
│   ├── onboard-client.sh
│   ├── remove-client.sh
│   └── update-client.sh        # (planned)
├── utilities/                  # General utility scripts
│   ├── backup-terraform-state.sh  # (planned)
│   ├── validate-configuration.sh  # (planned)
│   └── health-check.sh         # (planned)
└── README.md                   # This file
```

## Scripts Overview

### Deployment Scripts

#### `deployment/migrate-to-enhanced-architecture.sh`
**Purpose**: Safely migrates the existing production infrastructure to the new enhanced multi-tenant architecture.

**Features**:
- Zero-downtime migration with comprehensive backup
- State validation and rollback procedures
- Infrastructure state documentation
- Dry-run mode for testing
- Comprehensive logging and reporting

**Usage**:
```bash
# Dry run (recommended first)
./scripts/deployment/migrate-to-enhanced-architecture.sh dry-run

# Execute actual migration (when ready)
./scripts/deployment/migrate-to-enhanced-architecture.sh execute
```

**Prerequisites**:
- Terraform >= 1.0
- AWS credentials configured
- kubectl access to EKS cluster
- New architecture modules already created

**Safety Features**:
- Automatic backup of current configuration and state
- Detailed rollback instructions
- Infrastructure state documentation
- Pre-migration validation checks

### Client Management Scripts

#### `client-management/onboard-client.sh`
**Purpose**: Interactive script to onboard new clients to the multi-tenant infrastructure.

**Features**:
- Interactive client information collection
- Configuration validation (email, naming conventions)
- Tier-based resource allocation
- Environment-specific configuration generation
- Automatic documentation creation
- Deployment instructions generation

**Usage**:
```bash
./scripts/client-management/onboard-client.sh
```

**Generated Files**:
- `shared/client-configs/{client-name}/{environment}.tfvars`
- `shared/client-configs/{client-name}/README.md`
- `shared/client-configs/{client-name}/DEPLOYMENT_{ENVIRONMENT}.md`

**Client Tiers**:
- **Basic**: 4 CPU, 8Gi RAM, 100Gi storage
- **Standard**: 8 CPU, 16Gi RAM, 200Gi storage  
- **Premium**: 16 CPU, 32Gi RAM, 500Gi storage
- **Enterprise**: 32 CPU, 64Gi RAM, 1Ti storage

#### `client-management/remove-client.sh`
**Purpose**: Safely removes clients with proper cleanup and backup.

**Features**:
- Comprehensive backup before removal
- Running workload detection and graceful shutdown
- Kubernetes resource cleanup
- Infrastructure state documentation
- Rollback/recovery procedures
- Detailed removal reporting

**Usage**:
```bash
# Interactive mode
./scripts/client-management/remove-client.sh

# Direct client removal
./scripts/client-management/remove-client.sh client-name
```

**Safety Features**:
- Multiple confirmation prompts
- Running workload warnings
- Complete configuration backup
- Infrastructure state export
- Recovery documentation

## Configuration Management

### Client Configuration Structure

Each client has environment-specific configuration files:

```
shared/client-configs/
└── {client-name}/
    ├── production.tfvars      # Production environment settings
    ├── staging.tfvars         # Staging environment settings  
    ├── development.tfvars     # Development environment settings
    ├── README.md              # Client documentation
    └── DEPLOYMENT_*.md        # Environment deployment guides
```

### Configuration Schema

Client configuration files include:

- **Client metadata**: name, display name, contact, tier
- **Node group settings**: instance types, scaling, isolation
- **Resource quotas**: CPU, memory, storage limits
- **Networking**: external access, service mesh, security
- **Backup and monitoring**: retention, alerts, dashboards  
- **Security**: pod security standards, network policies

## Environment Architecture

The enhanced architecture supports multiple environments:

```
regions/us-east-1/
├── environments/
│   ├── production/           # Production environment
│   ├── staging/              # Staging environment
│   └── development/          # Development environment
└── clusters/
    └── production/           # Legacy structure (to be migrated)
```

## Deployment Workflow

### New Client Onboarding

1. **Run onboarding script**:
   ```bash
   ./scripts/client-management/onboard-client.sh
   ```

2. **Review generated configuration**:
   ```bash
   cat shared/client-configs/{client-name}/production.tfvars
   ```

3. **Deploy to environment**:
   ```bash
   cd regions/us-east-1/environments/production
   terraform plan -var-file="../../shared/client-configs/{client-name}/production.tfvars"
   terraform apply
   ```

4. **Verify deployment**:
   ```bash
   kubectl get nodes -l client={client-name}
   kubectl get namespace {client-name}-production
   ```

### Migration Process

1. **Run migration in dry-run mode**:
   ```bash
   ./scripts/deployment/migrate-to-enhanced-architecture.sh dry-run
   ```

2. **Review migration plan and backup**:
   ```bash
   # Review generated plan and backup files
   ls -la backup/
   ```

3. **Execute migration** (when ready):
   ```bash
   ./scripts/deployment/migrate-to-enhanced-architecture.sh execute
   ```

4. **Verify migration**:
   ```bash
   # Follow verification steps from migration report
   ```

### Client Removal Process

1. **Run removal script**:
   ```bash
   ./scripts/client-management/remove-client.sh {client-name}
   ```

2. **Review backup and removal report**:
   ```bash
   cat backup/client-removal/*/removal_report.md
   ```

3. **Verify cleanup** (follow report instructions):
   ```bash
   # Kubernetes cleanup verification
   kubectl get namespace {client-name}-*
   
   # AWS resource verification
   aws ec2 describe-instances --filters "Name=tag:Client,Values={client-name}"
   ```

## Security and Best Practices

### Access Control
- Scripts require appropriate AWS and Kubernetes permissions
- Client isolation can be enabled for sensitive workloads
- All actions are logged with timestamps and user information

### Data Protection
- Comprehensive backup before any destructive operations
- State files are preserved with rollback instructions
- Client data is backed up before removal

### Validation
- Configuration validation before deployment
- Resource limit enforcement based on client tier
- Pre-flight checks for migration and deployment

### Monitoring
- All operations generate detailed logs
- Infrastructure changes are documented
- Client resource usage is tracked and tagged

## Troubleshooting

### Common Issues

1. **Migration fails with state conflicts**:
   ```bash
   # Check current terraform state
   terraform state list
   
   # Review backup and rollback instructions
   cat backup/*/rollback_instructions.txt
   ```

2. **Client onboarding fails validation**:
   - Check client naming conventions (lowercase, alphanumeric, hyphens)
   - Verify email format
   - Ensure client doesn't already exist

3. **Removal script warnings about running workloads**:
   ```bash
   # Check client workloads
   kubectl get pods -n {client-name}-{environment}
   
   # Scale down manually if needed
   kubectl scale deployment {deployment} --replicas=0 -n {client-name}-{environment}
   ```

### Debug Mode

Enable debug mode for troubleshooting:
```bash
# Enable bash debug mode
bash -x ./scripts/client-management/onboard-client.sh

# Check generated logs
tail -f backup/*/migration.log
```

## Planned Enhancements

### Upcoming Features

1. **`deploy-environment.sh`**: Automated environment deployment
2. **`update-client.sh`**: Client configuration updates without recreation  
3. **`backup-terraform-state.sh`**: Automated state backup and rotation
4. **`validate-configuration.sh`**: Configuration validation and compliance checking
5. **`health-check.sh`**: Infrastructure health monitoring and reporting

### API Integration

Future versions will include:
- REST API for client management
- GitOps integration for configuration changes
- Automated compliance reporting
- Cost optimization recommendations

## Support and Maintenance

### Team Responsibilities

- **Platform Engineering**: Script maintenance, architecture updates
- **DevOps**: Deployment execution, troubleshooting  
- **Client Teams**: Configuration requirements, testing

### Contacts

- **Platform Engineering**: platform-engineering@company.com
- **DevOps On-Call**: devops-oncall@company.com
- **Documentation**: [Internal Wiki](docs/)

### Maintenance Schedule

- **Monthly**: Script updates and security patches
- **Quarterly**: Architecture review and optimization
- **Annually**: Major version upgrades and migrations

---

**Note**: These scripts are part of the enhanced multi-tenant Terraform architecture (Phase 3: Client Module Abstraction). They support the migration from the current architecture and provide ongoing client lifecycle management capabilities.

For detailed architecture documentation, see the [REFACTORING_PLAN.md](../REFACTORING_PLAN.md) and [SCALING_IMPROVEMENTS.md](../docs/SCALING_IMPROVEMENTS.md) files.
