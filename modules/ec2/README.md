# EC2 Module

A comprehensive, reusable Terraform module for creating EC2 instances with advanced features including EBS volume management, IAM roles, security groups, and client-isolation support.

## Features

- **Flexible Instance Configuration**: Support for any instance type, AMI, and configuration
- **Advanced Storage**: Multi-volume EBS support with encryption and custom configuration
- **IAM Integration**: Optional IAM role creation with SSM and CloudWatch policies
- **Security Groups**: Optional default security group creation or use existing groups
- **Client Isolation**: Built-in support for client-specific tagging and isolation
- **Monitoring**: CloudWatch monitoring and SSM access configuration
- **Compatibility**: Works with existing client-infrastructure module
- **Lifecycle Management**: Prevent destroy options and AMI change handling

## Usage Examples

### Basic Database Server

```hcl
module "database_server" {
  source = "../modules/ec2"
  
  # Basic configuration
  name          = "client-prod-database"
  ami_id        = "ami-0779caf41f9ba54f0"
  instance_type = "r5.large"
  key_name      = "terraform-key"
  subnet_id     = "subnet-0a6936df3ff9a4f77"
  
  # Security
  security_groups = ["sg-067bc5c25980da2cc"]
  disable_api_termination = true
  
  # Storage
  volume_size = 30
  volume_type = "gp3"
  root_volume_encrypted = true
  
  # Additional database volume
  extra_volumes = [{
    device_name = "/dev/sdf"
    size        = 50
    type        = "io2"
    iops        = 10000
    encrypted   = true
  }]
  
  # IAM and monitoring
  create_iam_role   = true
  enable_ssm        = true
  enable_monitoring = true
  
  # Tagging
  environment   = "production"
  service_type  = "database"
  client_name   = "ezra"
  
  tags = {
    Project = "ezra-prod"
    Owner   = "ezra-team"
  }
}
```

### Application Server with Load Balancer

```hcl
module "app_server" {
  source = "../modules/ec2"
  
  name          = "webapp-prod-server"
  ami_id        = "ami-0779caf41f9ba54f0"
  instance_type = "c5.xlarge"
  key_name      = "webapp-key"
  subnet_id     = "subnet-private-1"
  
  # Create default security group with SSH access
  create_default_security_group = true
  
  # Additional security groups for web access
  security_groups = ["sg-web-access", "sg-database-client"]
  
  # IAM role with additional policies
  create_iam_role = true
  additional_iam_policies = [
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  ]
  
  # User data for application setup
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker
    systemctl start docker
    systemctl enable docker
  EOF
  
  tags = {
    Environment = "production"
    Service     = "webapp"
    Backup      = "daily"
  }
}
```

### Compute Node for Batch Processing

```hcl
module "batch_compute" {
  source = "../modules/ec2"
  
  name          = "batch-compute-node"
  ami_id        = "ami-optimized-compute"
  instance_type = "c6i.4xlarge"
  subnet_id     = "subnet-compute-zone-a"
  
  # High-performance storage
  volume_type = "gp3"
  volume_size = 100
  volume_iops = 16000
  volume_throughput = 1000
  
  # Multiple data volumes
  extra_volumes = [
    {
      device_name = "/dev/sdf"
      size        = 1000
      type        = "gp3"
      iops        = 16000
      throughput  = 1000
    },
    {
      device_name = "/dev/sdg"
      size        = 500
      type        = "io2"
      iops        = 20000
    }
  ]
  
  # Performance optimization
  ebs_optimized = true
  enable_monitoring = true
  
  # Use existing IAM role
  iam_instance_profile = "batch-processing-role"
  
  environment  = "production"
  service_type = "compute"
}
```

### Development Environment

```hcl
module "dev_instance" {
  source = "../modules/ec2"
  
  name          = "developer-workstation"
  ami_id        = "ami-0779caf41f9ba54f0"
  instance_type = "t3.large"
  key_name      = "dev-team-key"
  subnet_id     = "subnet-dev-private"
  
  # Allow public IP for development
  associate_public_ip = true
  
  # Burstable performance
  cpu_credits = "unlimited"
  
  # Development-friendly settings
  disable_api_termination = false
  prevent_destroy = false
  ignore_ami_changes = true
  
  # Basic storage
  volume_size = 50
  root_volume_encrypted = false  # Dev environment
  
  create_iam_role = true
  enable_ssm = true
  
  environment = "development"
  service_type = "development"
  
  tags = {
    Team    = "engineering"
    Purpose = "development"
    Cost    = "dev"
  }
}
```

## Input Variables

### Core Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `name` | `string` | Required | Name for the EC2 instance and associated resources |
| `ami_id` | `string` | Required | AMI ID to use for the EC2 instance |
| `instance_type` | `string` | `"t3.micro"` | EC2 instance type |
| `key_name` | `string` | `""` | Name of the AWS key pair for SSH access |
| `subnet_id` | `string` | Required | ID of the subnet where the instance will be launched |
| `security_groups` | `list(string)` | `[]` | List of security group IDs to attach to the instance |

### Storage Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `volume_type` | `string` | `"gp3"` | Type of root EBS volume |
| `volume_size` | `number` | `20` | Size of root EBS volume in GB |
| `volume_iops` | `number` | `null` | IOPS for the root volume |
| `volume_throughput` | `number` | `null` | Throughput for gp3 volumes in MB/s |
| `root_volume_encrypted` | `bool` | `true` | Whether to encrypt the root EBS volume |
| `extra_volumes` | `list(object)` | `[]` | List of additional EBS volumes to create |

### Security and IAM

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `create_iam_role` | `bool` | `false` | Whether to create an IAM role and instance profile |
| `enable_ssm` | `bool` | `true` | Enable AWS Systems Manager access |
| `disable_api_termination` | `bool` | `false` | Enable EC2 instance termination protection |
| `create_default_security_group` | `bool` | `false` | Whether to create a default security group |

### Monitoring and Performance

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_monitoring` | `bool` | `true` | Enable detailed CloudWatch monitoring |
| `ebs_optimized` | `bool` | `null` | Enable EBS optimization for supported instance types |
| `cpu_credits` | `string` | `""` | Credit specification for burstable performance instances |

## Outputs

### Primary Outputs

| Output | Description |
|--------|-------------|
| `instance_id` | The ID of the EC2 instance |
| `instance_arn` | The ARN of the EC2 instance |
| `private_ip` | The private IP address of the EC2 instance |
| `public_ip` | The public IP address of the EC2 instance (if applicable) |
| `availability_zone` | The availability zone where the instance is deployed |

### Storage Outputs

| Output | Description |
|--------|-------------|
| `root_volume_id` | The ID of the root EBS volume |
| `additional_volume_ids` | List of additional EBS volume IDs |
| `volume_attachments` | Map of volume attachments with device names and volume IDs |

### IAM Outputs

| Output | Description |
|--------|-------------|
| `iam_role_arn` | The ARN of the IAM role (if created) |
| `iam_instance_profile_name` | The name of the IAM instance profile |

### Complete Summary

| Output | Description |
|--------|-------------|
| `instance_summary` | Complete summary of the EC2 instance and associated resources |

## Advanced Features

### Client Isolation

The module supports client-isolation patterns used in multi-tenant environments:

```hcl
module "client_database" {
  source = "../modules/ec2"
  
  name        = "client-prod-database"
  client_name = "ezra"  # Adds Client = "ezra" tag automatically
  
  # ... other configuration
}
```

### Multiple Volume Management

Attach multiple EBS volumes with different configurations:

```hcl
extra_volumes = [
  {
    device_name = "/dev/sdf"
    size        = 100
    type        = "gp3"
    iops        = 3000
    throughput  = 125
    encrypted   = true
    name        = "data-volume"
    tags = {
      Purpose = "application-data"
    }
  },
  {
    device_name = "/dev/sdg"
    size        = 50
    type        = "io2"
    iops        = 10000
    encrypted   = true
    name        = "logs-volume"
  }
]
```

### Lifecycle Management

Protect critical instances from accidental deletion:

```hcl
prevent_destroy         = true
disable_api_termination = true
ignore_ami_changes      = true
```

## Compatibility

This module is designed to be compatible with the existing `client-infrastructure` module. When used as a sub-module, it accepts the parameter mappings expected by the client-infrastructure module.

## Requirements

- Terraform >= 1.5.0
- AWS Provider ~> 5.0
- Appropriate AWS permissions for EC2, EBS, IAM resources

## Contributing

When adding new features:
1. Update variables.tf with new input parameters
2. Update outputs.tf with relevant outputs  
3. Add usage examples to this README
4. Test with various instance types and configurations

## License

This module is part of the internal infrastructure repository and follows the same licensing terms.
