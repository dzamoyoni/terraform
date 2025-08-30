data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

data "aws_region" "current" {}

# Create service account for External DNS
resource "kubernetes_service_account" "external_dns" {
  metadata {
    name      = var.service_account_name
    namespace = var.service_account_namespace

    annotations = {
      "eks.amazonaws.com/role-arn" = var.service_account_role_arn
    }

    labels = {
      "app.kubernetes.io/name"       = "external-dns"
      "app.kubernetes.io/component"  = "controller"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# Create RBAC for External DNS
resource "kubernetes_cluster_role" "external_dns" {
  metadata {
    name = "external-dns"
  }

  rule {
    api_groups = [""]
    resources  = ["services", "endpoints", "pods"]
    verbs      = ["get", "watch", "list"]
  }

  rule {
    api_groups = ["extensions", "networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "watch", "list"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "external_dns" {
  metadata {
    name = "external-dns-viewer"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.external_dns.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.external_dns.metadata[0].name
    namespace = kubernetes_service_account.external_dns.metadata[0].namespace
  }
}

# Deploy single External DNS instance for cluster-wide management
resource "kubernetes_deployment" "external_dns" {
  metadata {
    name      = "external-dns"
    namespace = var.service_account_namespace
    labels = {
      "app.kubernetes.io/name"       = "external-dns"
      "app.kubernetes.io/component"  = "controller"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    replicas = 1
    
    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "external-dns"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "external-dns"
          "app.kubernetes.io/component" = "controller"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.external_dns.metadata[0].name

        security_context {
          fs_group    = 65534
          run_as_user = 65534
        }

        container {
          name  = "external-dns"
          image = "registry.k8s.io/external-dns/external-dns:${var.external_dns_version}"

          # Build args with multiple domain filters
          args = concat([
            "--source=service",
            "--source=ingress"
          ], 
          # Add domain-filter for each domain
          [for domain in var.domain_filters : "--domain-filter=${domain}"],
          [
            "--provider=aws",
            "--policy=${var.policy}",
            "--aws-zone-type=public",
            "--registry=txt",
            "--txt-owner-id=${var.cluster_name}-external-dns",
            "--log-format=text",
            "--log-level=info"
          ], var.extra_args)

          env {
            name  = "AWS_REGION"
            value = data.aws_region.current.name
          }

          dynamic "env" {
            for_each = var.extra_env_vars
            content {
              name  = env.key
              value = env.value
            }
          }

          resources {
            limits = {
              memory = var.resources.limits.memory
              cpu    = var.resources.limits.cpu
            }
            requests = {
              memory = var.resources.requests.memory
              cpu    = var.resources.requests.cpu
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_account.external_dns,
    kubernetes_cluster_role_binding.external_dns
  ]
}
