terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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
}

provider "aws" {
  region = var.aws_region
}

# EKS data sources — only evaluated when deploy_addons=true.
# On phase-1 apply, no helm/k8s resources exist so these never run.
data "aws_eks_cluster" "main" {
  count = var.deploy_addons ? 1 : 0
  name  = module.eks[0].cluster_name
}

data "aws_eks_cluster_auth" "main" {
  count = var.deploy_addons ? 1 : 0
  name  = module.eks[0].cluster_name
}

provider "kubernetes" {
  host = var.deploy_addons ? data.aws_eks_cluster.main[0].endpoint : "https://localhost"
  cluster_ca_certificate = var.deploy_addons ? base64decode(
    data.aws_eks_cluster.main[0].certificate_authority[0].data
  ) : ""
  token = var.deploy_addons ? data.aws_eks_cluster_auth.main[0].token : ""
}

provider "helm" {
  kubernetes {
    host = var.deploy_addons ? data.aws_eks_cluster.main[0].endpoint : "https://localhost"
    cluster_ca_certificate = var.deploy_addons ? base64decode(
      data.aws_eks_cluster.main[0].certificate_authority[0].data
    ) : ""
    token = var.deploy_addons ? data.aws_eks_cluster_auth.main[0].token : ""
  }
}
