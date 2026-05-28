# ============================================================
#  terraform/modules/eks/addons.tf
#  Helm releases for ArgoCD and Prometheus/Grafana
#
#  FIXES:
#  1. prometheus timeout raised from 300 → 600 (fixes context deadline exceeded)
#  2. atomic = false so a timeout doesn't auto-delete what was partially deployed
#  3. cleanup_on_fail = false so a failed deploy leaves resources for debugging
# ============================================================

resource "helm_release" "argocd" {
  count = var.deploy_addons ? 1 : 0

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.4.5"
  namespace        = "argocd"
  create_namespace = true
  timeout          = 300
  wait             = true
  atomic           = false
  cleanup_on_fail  = false

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "server.extraArgs[0]"
    value = "--insecure"
  }
}

resource "helm_release" "prometheus" {
  count = var.deploy_addons ? 1 : 0

  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "86.0.1"
  namespace        = "monitoring"
  create_namespace = true

  # FIX: Raised from 300 to 600 — kube-prometheus-stack installs
  # Prometheus + Grafana + Alertmanager + CRDs simultaneously.
  # On a fresh cluster it needs ~8 minutes to pull images and reach Ready.
  timeout         = 600
  wait            = true
  atomic          = false   # Don't auto-rollback on timeout
  cleanup_on_fail = false   # Leave pods so you can debug with kubectl

  set {
    name  = "grafana.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "grafana.adminPassword"
    value = "WanderlustGrafana2024!"
  }
}

