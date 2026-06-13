output "vpc_id" {
  description = "Shared VPC ID"
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Shared public subnet IDs"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Shared private subnet IDs"
  value       = module.network.private_subnet_ids
}

output "ecr_repository_urls" {
  description = "Map of ECR repo name -> URL"
  value       = module.ecr.repository_urls
}