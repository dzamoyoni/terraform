variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "service_account_name" {
  description = "Name of the Kubernetes service account for External DNS"
  type        = string
  default     = "external-dns"
}

variable "service_account_namespace" {
  description = "Namespace for the External DNS service account"
  type        = string
  default     = "kube-system"
}

variable "service_account_role_arn" {
  description = "ARN of the IAM role to associate with the service account"
  type        = string
}

variable "domain_filters" {
  description = "List of domains that External DNS should manage"
  type        = list(string)
}

variable "external_dns_version" {
  description = "Version of External DNS to deploy"
  type        = string
  default     = "v0.14.0"
}

variable "policy" {
  description = "ExternalDNS policy for managing DNS records"
  type        = string
  default     = "sync"
  
  validation {
    condition     = contains(["sync", "upsert-only", "create-only"], var.policy)
    error_message = "Policy must be one of: sync, upsert-only, create-only."
  }
}

variable "extra_args" {
  description = "Additional arguments to pass to External DNS"
  type        = list(string)
  default     = []
}

variable "extra_env_vars" {
  description = "Additional environment variables for External DNS"
  type        = map(string)
  default     = {}
}

variable "zone_id_filters" {
  description = "List of Route53 hosted zone IDs that External DNS should manage. If empty, manages all zones for the domain filters."
  type        = list(string)
  default     = []
}

variable "resources" {
  description = "Resource requests and limits for External DNS pods"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "200m"
      memory = "256Mi"
    }
  }
}
