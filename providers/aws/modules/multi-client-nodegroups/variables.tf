variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the cluster is deployed"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet IDs for node groups"
  type        = list(string)
}

variable "environment" {
  description = "Environment name (e.g., production, staging, dev)"
  type        = string
  default     = "production"
}

variable "ec2_key_name" {
  description = "EC2 Key Pair name for SSH access to nodes (without .pem extension)"
  type        = string
  default     = null
}

variable "client_nodegroups" {
  description = "Map of client nodegroups with their configuration"
  type = map(object({
    # Instance configuration
    capacity_type  = string       # ON_DEMAND or SPOT
    instance_types = list(string) # List of instance types
    
    # Auto-scaling configuration
    desired_size = number
    max_size     = number
    min_size     = number
    
    # Update configuration
    max_unavailable_percentage = number # Percentage of nodes that can be unavailable during updates
    
    # Workload classification
    tier        = string # e.g., "general", "critical", "batch"
    workload    = string # e.g., "application", "batch-processing", "transaction-processing"
    performance = string # e.g., "standard", "high", "variable"
    
    # Isolation settings
    enable_client_isolation = bool # Whether to add client taint for isolation
    
    # Custom taints for specialized workloads
    custom_taints = list(object({
      key    = string
      value  = string
      effect = string # NO_SCHEDULE, NO_EXECUTE, or PREFER_NO_SCHEDULE
    }))
    
    # IP OPTIMIZATION FEATURES (NEW)
    # Strategy 1: Prefix Delegation
    enable_prefix_delegation = optional(bool, false)        # Enable IP prefix delegation
    max_pods_per_node       = optional(number, 17)         # Max pods per node (varies by instance type)
    
    # Strategy 2: Dedicated Subnets
    dedicated_subnet_ids    = optional(list(string), [])   # Client-specific subnet IDs
    
    # Advanced networking
    disk_size              = optional(number, 20)          # EBS disk size in GB
    bootstrap_extra_args   = optional(string, "")          # Additional kubelet bootstrap args
    use_launch_template    = optional(bool, false)         # Use launch template for advanced configs
    
    # Additional labels and tags
    extra_labels = map(string)
    extra_tags   = map(string)
  }))
  default = {}
}

# variable "enable_system_nodegroup" {
#   description = "Whether to create a shared system nodegroup for cluster system workloads"
#   type        = bool
#   default     = true
# }

# variable "system_nodegroup" {
#   description = "Configuration for the shared system nodegroup"
#   type = object({
#     capacity_type  = string       # ON_DEMAND or SPOT
#     instance_types = list(string) # List of instance types
#     desired_size   = number
#     max_size       = number
#     min_size       = number
#   })
#   default = {
#     capacity_type  = "ON_DEMAND"
#     instance_types = ["t3.medium", "t3.large"]
#     desired_size   = 1
#     max_size       = 3
#     min_size       = 1
#   }
# }
