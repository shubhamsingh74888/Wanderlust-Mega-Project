# This tells Terraform to manage Argo CD via Helm
resource "helm_release" "argocd" {
 count = var.deploy_addons ? 1 : 0
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "7.0.0"

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }
}
