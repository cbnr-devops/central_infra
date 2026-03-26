module "vpc" {
  source     = "../../modules/vpc"
  env        = "dev"
  aws_region = var.aws_region
  vpc_cidr   = var.vpc_cidr
}

module "eks" {
  source         = "../../modules/eks"
  cluster_name   = "dev-cluster"
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnets
  instance_types = var.instance_types
}
