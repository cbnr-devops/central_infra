output "vpc_id" {
  description = "ID of the dev VPC"
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs in the dev VPC"
  value       = module.network.public_subnet_ids
}

output "eks_subnet_id" {
  description = "Subnet ID to use for EKS nodes"
  value       = module.network.private_subnet_ids[0]
}

output "db_subnet_id" {
  description = "Subnet ID to use for the RDS instance"
  value       = module.network.private_subnet_ids[1]
}

output "cluster_oidc_issuer" {
  description = "OIDC issuer URL for dev EKS"
  value       = module.eks.cluster_oidc_issuer
}