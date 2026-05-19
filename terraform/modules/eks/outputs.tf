# ============================================================
# EKS Module Output Configurations
# Exposes Core Platform Control Plane Metrics to Root Resource Providers
# ============================================================

output "cluster_name" {
  description = "The unique identifier tag assigned to the managed EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "The public/private URL address for the Kubernetes API server control plane"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "The base64 encoded certificate authority credentials required to establish TLS tunnels"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "node_group_arn" {
  description = "The Amazon Resource Name mapping directly to the provisioned EC2 managed worker node pool"
  value       = aws_eks_node_group.main.arn
}
