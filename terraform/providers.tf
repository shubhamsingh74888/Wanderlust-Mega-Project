# ============================================================
# Root Orchestration Provider Constraints
# ============================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.91.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

# AWS Provider — Automatically inherits active authorization profiles from your shell environment
provider "aws" {
  region = var.aws_region
}

# ── NOTE: Kubernetes and Helm providers are currently commented out 
# ── because the 'eks' module has not yet been deployed. 
# ── Uncomment these blocks once your EKS cluster module is defined in main.tf.

# provider "kubernetes" {
#   host                   = module.eks.cluster_endpoint
#   cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
#
#   exec {
#     api_version = "client.authentication.k8s.io/v1beta1"
#     command     = "aws"
#     args = [
#       "eks", "get-token",
#       "--cluster-name", module.eks.cluster_name,
#       "--region", var.aws_region
#     ]
#   }
# }

# provider "helm" {
#   kubernetes {
#     host                   = module.eks.cluster_endpoint
#     cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
#
#     exec {
#       api_version = "client.authentication.k8s.io/v1beta1"
#       command     = "aws"
#       args = [
#         "eks", "get-token",
#         "--cluster-name", module.eks.cluster_name,
#         "--region", var.aws_region
#       ]
#     }
#   }
# }
