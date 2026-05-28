# ============================================================
# EKS Addons Module
# Handles Helm-based deployments for ArgoCD and Monitoring.
# Uses 'deploy_addons' toggle to prevent race conditions.
# ============================================================

resource "helm_release" "argocd" {
  count            = var.deploy_addons ? 1 : 0
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  timeout = 600 # Increase to 10 minutes (600 seconds)
  wait    = true
  version          = "7.4.5" # Pinning version for stability

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "server.extraArgs[0]"
    value = "--insecure" # Note: Use TLS/Ingress for production
  }
}

resource "helm_release" "prometheus" {
  count            = var.deploy_addons ? 1 : 0
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true

  set {
    name  = "grafana.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "grafana.adminPassword"
    value = "WanderlustGrafana2024!" # TODO: Replace with AWS Secrets Manager lookup
  }
}
