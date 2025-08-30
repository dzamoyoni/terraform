variable "vpc_id" {
  description = "VPC ID where tenant subnets will be created"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., production, staging, dev)"
  type        = string
}

variable "tenant_base_cidr" {
  description = "Base CIDR block for tenant subnets (e.g., '172.20.10.0/22')"
  type        = string
  validation {
    condition     = can(cidrhost(var.tenant_base_cidr, 0))
    error_message = "Tenant base CIDR must be a valid CIDR block."
  }
}

variable "tenant_configs" {
  description = "Configuration for tenant subnets"
  type = map(object({
    tenant_index        = number       # Unique index for CIDR calculation (0, 1, 2, etc.)
    subnet_count        = number       # Number of subnets per tenant (usually 2 for HA)
    subnet_size_bits    = number       # Additional bits for subnet sizing (e.g., 2 for /24 from /22)
    allowed_cidr_block  = string       # CIDR block allowed for tenant communication
  }))
  
  validation {
    condition = alltrue([
      for tenant, config in var.tenant_configs : 
      config.subnet_count >= 1 && config.subnet_count <= 6
    ])
    error_message = "Each tenant must have between 1 and 6 subnets."
  }
  
  validation {
    condition = alltrue([
      for tenant, config in var.tenant_configs : 
      config.subnet_size_bits >= 1 && config.subnet_size_bits <= 8
    ])
    error_message = "Subnet size bits must be between 1 and 8."
  }
}

variable "nat_gateway_id" {
  description = "NAT Gateway ID for outbound internet access"
  type        = string
  default     = ""
}

variable "cluster_service_cidr" {
  description = "Kubernetes service CIDR block"
  type        = string
  default     = "10.100.0.0/16"
}

variable "enable_network_acls" {
  description = "Enable Network ACLs for additional tenant isolation"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "terraform"
    Feature   = "tenant-isolation"
  }
}
