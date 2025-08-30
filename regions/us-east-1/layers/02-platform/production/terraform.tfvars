# ============================================================================
# Platform Layer Configuration (02-platform/production)
# ============================================================================
# Configuration for the EKS cluster and shared platform services

# Basic Configuration
aws_region   = "us-east-1"
environment  = "production"
cluster_name = "us-test-cluster-01"

# EBS CSI Driver
ebs_csi_addon_version = "v1.35.0-eksbuild.1"

# DNS Configuration
enable_external_dns = true
dns_zones = {
  "stacai.ai" = {
    comment     = "DNS zone for MTN Ghana production services"
    environment = "production"
    client      = "mtn-ghana"
  },
  "ezra.world" = {
    comment     = "DNS zone for Ezra client production services"
    environment = "production"
    client      = "ezra"
  }
}

# IngressClass Configuration
alb_ingress_class_name         = "alb"
set_alb_as_default            = true
create_nlb_ingress_class      = false
nlb_ingress_class_name        = "nlb"
nlb_scheme                    = "internet-facing"
create_nginx_ingress_class    = false
nginx_ingress_class_name      = "nginx"

# ============================================================================
# Istio Service Mesh Configuration
# ============================================================================
enable_istio                 = false  # Using istioctl instead of Helm module
istio_version               = "1.27.0"
istio_ambient_mode          = true
istio_ingress_gateway       = true
istio_egress_gateway        = false
istio_ingress_gateway_type  = "ClusterIP"
istio_monitoring            = true
istio_ambient_namespaces    = []
