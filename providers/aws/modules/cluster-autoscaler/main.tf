# Cluster Autoscaler Module
# Deploys cluster autoscaler with proper IAM roles and service account

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

# Extract OIDC issuer URL from the ARN
locals {
  oidc_issuer_url = replace(var.cluster_oidc_issuer_url, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/", "")
}

# IAM role for cluster autoscaler
resource "aws_iam_role" "cluster_autoscaler" {
  name = "${var.cluster_name}-cluster-autoscaler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.cluster_oidc_issuer_url
        }
        Condition = {
          StringEquals = {
            "${local.oidc_issuer_url}:sub" = "system:serviceaccount:kube-system:cluster-autoscaler"
            "${local.oidc_issuer_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-cluster-autoscaler"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# IAM policy for cluster autoscaler
resource "aws_iam_policy" "cluster_autoscaler" {
  name        = "${var.cluster_name}-cluster-autoscaler"
  path        = "/"
  description = "Policy for cluster autoscaler"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-cluster-autoscaler"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  role       = aws_iam_role.cluster_autoscaler.name
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
}

# Kubernetes service account
resource "kubernetes_service_account" "cluster_autoscaler" {
  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"
    
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.cluster_autoscaler.arn
    }
    
    labels = {
      "app.kubernetes.io/component" = "cluster-autoscaler"
      "app.kubernetes.io/name"      = "cluster-autoscaler"
    }
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_autoscaler]
}

# Cluster role
resource "kubernetes_cluster_role" "cluster_autoscaler" {
  metadata {
    name = "cluster-autoscaler"
    
    labels = {
      "app.kubernetes.io/component" = "cluster-autoscaler"
      "app.kubernetes.io/name"      = "cluster-autoscaler"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["events", "endpoints"]
    verbs      = ["create", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/eviction"]
    verbs      = ["create"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/status"]
    verbs      = ["update"]
  }

  rule {
    api_groups     = [""]
    resources      = ["endpoints"]
    resource_names = ["cluster-autoscaler"]
    verbs          = ["get", "update"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["watch", "list", "get", "update"]
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces", "pods", "services", "replicationcontrollers", "persistentvolumeclaims", "persistentvolumes"]
    verbs      = ["watch", "list", "get"]
  }

  rule {
    api_groups = ["extensions"]
    resources  = ["replicasets", "daemonsets"]
    verbs      = ["watch", "list", "get"]
  }

  rule {
    api_groups = ["policy"]
    resources  = ["poddisruptionbudgets"]
    verbs      = ["watch", "list"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["statefulsets", "replicasets", "daemonsets"]
    verbs      = ["watch", "list", "get"]
  }

  rule {
    api_groups = ["storage.k8s.io"]
    resources  = ["storageclasses", "csinodes", "csidrivers", "csistoragecapacities"]
    verbs      = ["watch", "list", "get"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs", "cronjobs"]
    verbs      = ["watch", "list", "get"]
  }

  rule {
    api_groups = ["coordination.k8s.io"]
    resources  = ["leases"]
    verbs      = ["create"]
  }

  rule {
    api_groups     = ["coordination.k8s.io"]
    resources      = ["leases"]
    resource_names = ["cluster-autoscaler"]
    verbs          = ["get", "update"]
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["create", "list", "watch"]
  }

  rule {
    api_groups     = [""]
    resources      = ["configmaps"]
    resource_names = ["cluster-autoscaler-status"]
    verbs          = ["delete", "get", "update"]
  }
}

# Cluster role binding
resource "kubernetes_cluster_role_binding" "cluster_autoscaler" {
  metadata {
    name = "cluster-autoscaler"
    
    labels = {
      "app.kubernetes.io/component" = "cluster-autoscaler"
      "app.kubernetes.io/name"      = "cluster-autoscaler"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.cluster_autoscaler.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.cluster_autoscaler.metadata[0].name
    namespace = "kube-system"
  }
}

# Cluster autoscaler deployment
resource "kubernetes_deployment" "cluster_autoscaler" {
  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"
    
    labels = {
      "app.kubernetes.io/component" = "cluster-autoscaler"
      "app.kubernetes.io/name"      = "cluster-autoscaler"
      "app.kubernetes.io/version"   = var.autoscaler_version
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/component" = "cluster-autoscaler"
        "app.kubernetes.io/name"      = "cluster-autoscaler"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/component" = "cluster-autoscaler"
          "app.kubernetes.io/name"      = "cluster-autoscaler"
          "app.kubernetes.io/version"   = var.autoscaler_version
        }
        
        annotations = {
          "prometheus.io/port"   = "8085"
          "prometheus.io/scrape" = "true"
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
        priority_class_name                   = "system-cluster-critical"
        security_context {
          run_as_non_root = true
          run_as_user     = 65534
          fs_group        = 65534
        }
        service_account_name = kubernetes_service_account.cluster_autoscaler.metadata[0].name

        container {
          name              = "cluster-autoscaler"
          image             = "registry.k8s.io/autoscaling/cluster-autoscaler:${var.autoscaler_version}"
          image_pull_policy = "Always"

          resources {
            limits = {
              cpu    = "100m"
              memory = "600Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "600Mi"
            }
          }

          command = [
            "./cluster-autoscaler",
            "--v=4",
            "--stderrthreshold=info",
            "--cloud-provider=aws",
            "--skip-nodes-with-local-storage=false",
            "--expander=least-waste",
            "--node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/${var.cluster_name}",
            "--balance-similar-node-groups",
            "--skip-nodes-with-system-pods=false"
          ]

          env {
            name  = "AWS_REGION"
            value = data.aws_region.current.name
          }

          env {
            name  = "AWS_STS_REGIONAL_ENDPOINTS"
            value = "regional"
          }

          volume_mount {
            name       = "ssl-certs"
            mount_path = "/etc/ssl/certs/ca-certificates.crt"
            read_only  = true
          }

          liveness_probe {
            http_get {
              path = "/health-check"
              port = 8085
            }
            initial_delay_seconds = 600
            period_seconds        = 60
          }
        }

        volume {
          name = "ssl-certs"
          host_path {
            path = "/etc/ssl/certs/ca-bundle.crt"
          }
        }

        node_selector = {
          "kubernetes.io/os" = "linux"
        }

        toleration {
          effect   = "NoSchedule"
          operator = "Equal"
          key      = "CriticalAddonsOnly"
          value    = "true"
        }

        toleration {
          effect   = "NoSchedule"
          operator = "Equal"
          key      = "node-role.kubernetes.io/control-plane"
        }

        toleration {
          effect   = "NoSchedule"
          operator = "Equal"
          key      = "client"
          value    = "ezra"
        }

        toleration {
          effect   = "NoSchedule"
          operator = "Equal"
          key      = "client"
          value    = "mtn-ghana"
        }
      }
    }
  }

  depends_on = [kubernetes_cluster_role_binding.cluster_autoscaler]
}
