terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
  required_version = ">= 1.3"
}

# ── Providers ─────────────────────────────────────────────────────────────────
provider "digitalocean" {
  token = var.do_token
}

provider "helm" {
  kubernetes {
    host  = digitalocean_kubernetes_cluster.main.endpoint
    token = digitalocean_kubernetes_cluster.main.kube_config[0].token
    cluster_ca_certificate = base64decode(
      digitalocean_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate
    )
  }
}

provider "kubernetes" {
  host  = digitalocean_kubernetes_cluster.main.endpoint
  token = digitalocean_kubernetes_cluster.main.kube_config[0].token
  cluster_ca_certificate = base64decode(
    digitalocean_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate
  )
}

# ── Cluster ───────────────────────────────────────────────────────────────────
resource "digitalocean_kubernetes_cluster" "main" {
  name    = var.cluster_name
  region  = var.region
  version = var.k8s_version

  node_pool {
    name       = "worker-pool"
    size       = "s-1vcpu-2gb"
    node_count = 2
    tags       = [var.cluster_name, "terraform"]
  }

  auto_upgrade  = false
  surge_upgrade = true
  ha            = false

  maintenance_policy {
    start_time = "03:00"
    day        = "sunday"
  }
}

resource "local_file" "kubeconfig" {
  content         = digitalocean_kubernetes_cluster.main.kube_config[0].raw_config
  filename        = "${path.module}/kubeconfig.yaml"
  file_permission = "0600"
}

# ── Namespaces ────────────────────────────────────────────────────────────────
resource "kubernetes_namespace" "namespaces" {
  for_each = toset(["chaos-mesh", "k6", "trivy-system", "goldilocks"])

  metadata {
    name = each.key
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [digitalocean_kubernetes_cluster.main]
}

# ── Chaos Mesh ────────────────────────────────────────────────────────────────
resource "helm_release" "chaos_mesh" {
  name       = "chaos-mesh"
  repository = "https://charts.chaos-mesh.org"
  chart      = "chaos-mesh"
  version    = var.chaos_mesh_version
  namespace  = "chaos-mesh"

  set {
    name  = "chaosDaemon.runtime"
    value = "containerd"
  }
  set {
    name  = "chaosDaemon.socketPath"
    value = "/run/containerd/containerd.sock"
  }
  set {
    name  = "dashboard.create"
    value = "true"
  }
  # NodePort for external access
  set {
    name  = "dashboard.service.type"
    value = "NodePort"
  }
  set {
    name  = "dashboard.service.nodePort"
    value = tostring(var.nodeport_chaos_mesh)
  }

  wait    = true
  timeout = 300

  depends_on = [kubernetes_namespace.namespaces]
}

# Chaos Mesh RBAC
resource "kubernetes_service_account" "chaos_admin" {
  metadata {
    name      = "chaos-dashboard-admin"
    namespace = "chaos-mesh"
  }
  depends_on = [helm_release.chaos_mesh]
}

resource "kubernetes_cluster_role_binding" "chaos_admin" {
  metadata {
    name = "chaos-dashboard-admin"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "chaos-dashboard-admin"
    namespace = "chaos-mesh"
  }
  depends_on = [kubernetes_service_account.chaos_admin]
}

# ── k6 Operator ───────────────────────────────────────────────────────────────
resource "helm_release" "k6_operator" {
  name       = "k6-operator"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "k6-operator"
  namespace  = "k6"

  wait    = true
  timeout = 300

  depends_on = [kubernetes_namespace.namespaces]
}

# ── Trivy Operator ────────────────────────────────────────────────────────────
resource "helm_release" "trivy_operator" {
  name       = "trivy-operator"
  repository = "https://aquasecurity.github.io/helm-charts"
  chart      = "trivy-operator"
  version    = var.trivy_version
  namespace  = "trivy-system"

  set {
    name  = "trivy.ignoreUnfixed"
    value = "true"
  }
  set {
    name  = "operator.vulnerabilityScanner.enabled"
    value = "true"
  }
  set {
    name  = "operator.configAuditScanner.enabled"
    value = "true"
  }

  wait    = true
  timeout = 300

  depends_on = [kubernetes_namespace.namespaces]
}

# ── Goldilocks ────────────────────────────────────────────────────────────────
resource "helm_release" "goldilocks" {
  name       = "goldilocks"
  repository = "https://charts.fairwinds.com/stable"
  chart      = "goldilocks"
  namespace  = "goldilocks"

  set {
    name  = "dashboard.service.type"
    value = "NodePort"
  }
  set {
    name  = "dashboard.service.nodePort"
    value = tostring(var.nodeport_goldilocks)
  }

  wait    = true
  timeout = 300

  depends_on = [kubernetes_namespace.namespaces]
}

# Enable Goldilocks for default namespace
resource "kubernetes_labels" "goldilocks_default" {
  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = "default"
  }
  labels = {
    "goldilocks.fairwinds.com/enabled" = "true"
  }
  depends_on = [helm_release.goldilocks]
}

# ── kube-bench Job ────────────────────────────────────────────────────────────
resource "kubernetes_job" "kube_bench" {
  metadata {
    name      = "kube-bench"
    namespace = "default"
  }
  spec {
    template {
      metadata {}
      spec {
        host_pid = true
        container {
          name    = "kube-bench"
          image   = "aquasec/kube-bench:latest"
          command = ["kube-bench", "--benchmark", "cis-1.8"]
          volume_mount {
            name       = "var-lib-kubelet"
            mount_path = "/var/lib/kubelet"
            read_only  = true
          }
          volume_mount {
            name       = "etc-kubernetes"
            mount_path = "/etc/kubernetes"
            read_only  = true
          }
        }
        volume {
          name = "var-lib-kubelet"
          host_path { path = "/var/lib/kubelet" }
        }
        volume {
          name = "etc-kubernetes"
          host_path { path = "/etc/kubernetes" }
        }
        restart_policy = "Never"
      }
    }
    backoff_limit = 1
  }
  wait_for_completion = false
  depends_on          = [digitalocean_kubernetes_cluster.main]
}
