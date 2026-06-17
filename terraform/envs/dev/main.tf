data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "${var.project}-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Carve /20 private + /24 public subnets out of the VPC CIDR per AZ.
  private_subnets = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 48)]

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

########################################
# VPC
########################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "${local.name}-vpc"
  cidr = var.vpc_cidr
  azs  = local.azs

  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  # NAT Gateway is NOT free (~$33/mo). It only exists with the compute layer so a
  # cost-saving teardown (enable_compute=false) removes it while keeping the VPC.
  enable_nat_gateway = var.enable_compute
  single_nat_gateway = true # one NAT to save cost in the POC
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags required for EKS + AWS Load Balancer Controller subnet discovery.
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${local.name}-eks"   = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${local.name}-eks"   = "shared"
  }

  tags = local.tags
}

########################################
# EKS
########################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  # EKS control plane + nodes are the biggest cost; gate them behind the toggle.
  create = var.enable_compute

  cluster_name    = "${local.name}-eks"
  cluster_version = var.cluster_version

  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.cluster_public_access_cidrs

  # Grant the identity running Terraform cluster-admin so kubectl/helm work immediately.
  enable_cluster_creator_admin_permissions = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  enable_irsa = true

  cluster_addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }
  }

  eks_managed_node_groups = {
    default = {
      instance_types = [var.node_instance_type]
      capacity_type  = var.node_capacity_type

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      labels = {
        role = "general"
      }

      # Tags consumed by Cluster Autoscaler auto-discovery.
      tags = {
        "k8s.io/cluster-autoscaler/enabled"             = "true"
        "k8s.io/cluster-autoscaler/${local.name}-eks"   = "owned"
      }
    }
  }

  tags = local.tags
}

########################################
# IRSA roles for cluster add-ons
########################################
module "lb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  count = var.enable_compute ? 1 : 0

  role_name                              = "${local.name}-alb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.tags
}

module "cluster_autoscaler_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  count = var.enable_compute ? 1 : 0

  role_name                        = "${local.name}-cluster-autoscaler"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [module.eks.cluster_name]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }

  tags = local.tags
}

########################################
# ECR
########################################
resource "aws_ecr_repository" "app" {
  name                 = "${var.project}/app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # allow clean teardown even with images present

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.tags
}

########################################
# RDS PostgreSQL
########################################
resource "random_password" "db" {
  length  = 20
  special = false
}

resource "aws_security_group" "rds" {
  name        = "${local.name}-rds"
  description = "Allow PostgreSQL from within the VPC"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.7"

  identifier = "${local.name}-pg"

  engine               = "postgres"
  engine_version       = "16"
  family               = "postgres16"
  major_engine_version = "16"
  instance_class       = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 2
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = 5432

  # We manage the password ourselves (no Secrets Manager) for simple POC wiring.
  manage_master_user_password = false

  multi_az               = var.db_multi_az
  vpc_security_group_ids = [aws_security_group.rds.id]

  create_db_subnet_group = true
  subnet_ids             = module.vpc.private_subnets

  maintenance_window      = "Mon:00:00-Mon:03:00"
  backup_window           = "03:00-06:00"
  backup_retention_period = 1

  deletion_protection = false
  skip_final_snapshot = true

  performance_insights_enabled = false

  tags = local.tags
}

########################################
# Optional: GitHub Actions OIDC + CI role
########################################
module "github_oidc" {
  source = "../../modules/github-oidc"
  count  = var.enable_github_oidc ? 1 : 0

  name        = local.name
  github_repo = var.github_repo
  ecr_arn     = aws_ecr_repository.app.arn
  region      = var.region
  tags        = local.tags
}
