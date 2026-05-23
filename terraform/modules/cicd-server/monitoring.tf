resource "helm_release" "prometheus" {
  count = 0
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true

  set {
    name  = "grafana.service.type"
    value = "LoadBalancer"
  }
}
