module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.21.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.29"

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  enable_irsa                    = true
  cluster_endpoint_public_access = true

  manage_aws_auth_configmap = true

  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::312018064574:user/ec2-cli-user"
      username = "ec2-cli-user"
      groups   = ["system:masters"]
    }
  ]

  create_kms_key            = false
  cluster_encryption_config = []

  eks_managed_node_groups = {
    default = {
      instance_types = var.instance_types
      min_size       = 2
      max_size       = 3
      desired_size   = 2
    }
  }
}
