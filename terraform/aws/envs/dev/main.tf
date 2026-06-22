terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "network" {
  source = "../../modules/network"

  env      = var.env
  vpc_cidr = var.vpc_cidr

  azs = [var.az]

  public_subnet_cidrs = [
    var.public_subnet_cidr,
  ]

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

  env            = var.env
  cluster_name   = var.eks_cluster_name
  cluster_version = var.eks_version
  vpc_id          = module.network.vpc_id

  private_subnet_ids = [module.network.private_subnet_ids[0]]

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

  env   = var.env
  vpc_id = module.network.vpc_id

  private_subnet_ids = [module.network.private_subnet_ids[1]]

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
    module.rds_postgres.db_secret_arn 
  ]

  tags = {
    Owner = "sai"
  }
}

module "observability" {
  source = "../../modules/observability"

  env               = "dev"
  region            = var.region

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_ca        = module.eks.cluster_ca
  oidc_provider_arn = module.eks.oidc_provider_arn
}