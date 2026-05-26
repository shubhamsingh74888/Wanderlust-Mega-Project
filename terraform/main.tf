# ============================================================
# Root Module — Wanderlust Infrastructure
# Deploy order: VPC → CI/CD Server → EKS → Addons
# ============================================================

# ── Step 1: Build the Network ────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  project              = var.project
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

# ── Step 2: Build the Jenkins CI/CD Server ───────────────────
module "cicd_server" {
  source = "./modules/cicd-server"

  project          = var.project
  environment      = var.environment
  aws_region       = var.aws_region
  vpc_id           = module.vpc.vpc_id
  subnet_id        = module.vpc.public_subnet_ids[0]
  instance_type    = var.jenkins_instance_type
  ami_id           = var.jenkins_ami_id
  root_volume_size = var.jenkins_volume_size
  data_volume_size = var.jenkins_data_volume_size
  backup_s3_bucket = var.backup_s3_bucket
  deploy_addons    = var.deploy_addons
  availability_zone = var.availability_zones[0]    # Mapping from your VPC AZs
  ebs_volume_size   = var.jenkins_data_volume_size # Mapping to your existing volume var
  key_name          = var.key_name
}

# ── Step 3: Build the EKS Cluster ────────────────────────────
module "eks" {
  source = "./modules/eks"
  count         = var.deploy_eks ? 1 : 0
  project              = var.project
  environment          = var.environment
  aws_region           = var.aws_region
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  public_subnet_ids    = module.vpc.public_subnet_ids
  cluster_version      = var.eks_cluster_version
  node_instance_type   = var.eks_node_instance_type
  node_min_size        = var.eks_node_min_size
  node_max_size        = var.eks_node_max_size
  node_desired_size    = var.eks_node_desired_size
  jenkins_server_sg_id = module.cicd_server.security_group_id
  deploy_addons = var.deploy_addons
}

