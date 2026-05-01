# EKS Cluster Confiuguration with custom modules

#Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# VPC Module
module "vpc" {
  source      = "./modules/vpc"
  name_prefix = "eks-cluster"
  vpc_cidr    = var.vpc_cidr
  public_subnets = var.public_subnets
  private_subnets = var.private_subnets
  azs       = slice(data.aws_availability_zones.available.names, 0, 3)

enable_nat_gateway = true
single_nat_gateway = true

# Required tags for EKS
public_subnet_tags = {
  "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
}

private_subnet_tags = {
  "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
}

tags = {
  "Environment" = "production"
    "Project"     = "EKS-Terraform"
}

}

# Custom IAM Module
module "iam" {
  source      = "./modules/iam"
  
  cluster_name = var.cluster_name

  tags = {
    Environment = var.environment
    Terraform   = "true"
    "Project"     = "EKS-Terraform"
  }
}

# EKS Cluster Module
module "eks" {
  source      = "./modules/eks"
  
  cluster_name    = var.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets

  cluster_role_arn = module.iam.cluster_role_arn
  node_role_arn    = module.iam.node_role_arn

  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs = ["0.0.0.0/0"]

  enable_irsa = true

  node_groups = {
    general = {
      instance_type   = "t3.medium"
      desired_capacity = 2
      max_capacity     = 4
      min_capacity     = 2
      capacity_type     = "ON_DEMAND"
      disk_size        = 20

      labels = {
        "role" = "general"
      }

      tags = {
        NodeGroup = "general"
      }
    }

    spot = {
      instance_type   = ["t3.medium", "t3a.medium"]
      desired_size = 1
      max_size     = 3
      min_size    = 1
      capacity_type     = "SPOT"
      disk_size        = 20

      labels = {
        "role" = "spot"
      }

      taints = {
        NodeGroup = "spot"
      }

      tags = {
        NodeGroup = "spot"
      }
    }

  }


  

  tags = {
    Environment = var.environment
    Terraform   = "true"
    "Project"     = "EKS-Terraform"
  }

  depends_on = [ module.iam ]
}

# Custom Secrets Manager Module
module "secrets_manager" {
  source      = "./modules/secrets-manager"
  
  name_prefix = var.cluster_name

  #Enable secrets as needed
  create_db_secret = var.enable_db_secret
  create_api_secret = var.enable_api_secret
  create_create_app_config_secret = var.enable_app_config_secret

  # Database credentials (only needed if create_db_secret is true)
    db_username = var.db_username
    db_password = var.db_password
    db_engine   = var.db_engine
    db_host     = var.db_host
    db_port     = var.db_port
    db_name     = var.db_name
  
  # API key (only needed if create_api_secret is true)
    api_key = var.api_key
    api_secret = var.api_secret

    # Application configuration (only needed if create_app_config_secret is true)
    app_config = var.app_config

    tags = {
      Environment = var.environment
      Terraform   = "true"
      "Project"     = "EKS-Terraform"
    }
}