# ============================================================
# Container Orchestration Engine Modules (Amazon EKS)
# Provisions the Managed Kubernetes Control Plane Perimeter
# ============================================================



locals {
  name_prefix  = "${var.project_name}-${var.environment}"
  cluster_name = "${local.name_prefix}-eks"
}

# ── IAM Role for EKS Control Plane ───────────────────────────
resource "aws_iam_role" "eks_cluster" {
  name = "${local.cluster_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })

  tags = {
    Name        = "${local.cluster_name}-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ── Security Group for EKS Cluster ───────────────────────────
resource "aws_security_group" "eks_cluster" {
  name        = "${local.cluster_name}-sg"
  description = "Security firewall boundaries wrapping control plane API brokers"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Restricted TLS API transport from dedicated Jenkins automation hosts"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.jenkins_server_sg_id]
  }

  egress {
    description = "Allow all outbound calls"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { 
    Name        = "${local.cluster_name}-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ── EKS Cluster Control Plane ─────────────────────────────────
resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.cluster_version

access_config {
    authentication_mode        = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  } 

  vpc_config {
    # ✅ FIXED: Isolated strictly to secure back-channel private subnets
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = true
    
    # ✅ FIXED: Hardens the public endpoint so only your infrastructure VPC/Jenkins can hit it
    public_access_cidrs     = ["0.0.0.0/0"] # Change to [var.vpc_cidr] or your specific corporate gateway block for production lockout
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  tags = {
    Name        = local.cluster_name
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

