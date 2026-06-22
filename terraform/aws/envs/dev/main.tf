terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks.cluster_name,
      ]
    }
  }
}

module "network" {
  source = "../../modules/network"

  env      = var.env
  vpc_cidr = var.vpc_cidr

  azs = var.azs

  public_subnet_cidrs = var.public_subnet_cidrs

  private_subnet_cidrs = [
    var.eks_subnet_cidr,
    var.db_subnet_cidr,
  ]

  enable_nat_gateway = true

  tags = {
    Owner = "sai"
  }
}

module "eks" {
  source = "../../modules/eks"

  env             = var.env
  cluster_name    = var.eks_cluster_name
  cluster_version = var.eks_version
  vpc_id          = module.network.vpc_id

  private_subnet_ids = module.network.private_subnet_ids

  desired_capacity = var.eks_node_desired_size
  min_size         = var.eks_node_min_size
  max_size         = var.eks_node_max_size

  instance_type = var.eks_node_instance_type

  tags = {
    Owner = "sai"
  }
}

module "rds_postgres" {
  source = "../../modules/rds-postgresql"

  env    = var.env
  vpc_id = module.network.vpc_id

  private_subnet_ids = module.network.private_subnet_ids

  db_secret_name = var.db_secret_name

  engine_version    = var.db_engine_version
  instance_class    = var.db_instance_class
  db_name           = var.db_name
  allocated_storage = var.db_allocated_storage

  deletion_protection = var.db_deletion_protection
  multi_az            = var.db_multi_az

  tags = {
    Owner = "sai"
  }
}

module "irsa_secretsmanager_db" {
  source = "../../modules/irsa-secretsmanager"

  env                 = var.env
  cluster_oidc_issuer = module.eks.cluster_oidc_issuer

  service_account_namespace = var.irsa_sa_namespace
  service_account_name      = var.irsa_sa_name

  secret_arns = [
    module.rds_postgres.secret_arn,
  ]

  tags = {
    Owner = "sai"
  }
}

module "observability" {
  source = "../../modules/observability"

  env    = "dev"
  region = var.aws_region

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_ca        = module.eks.cluster_certificate_authority
  oidc_provider_arn = module.eks.oidc_provider_arn
}