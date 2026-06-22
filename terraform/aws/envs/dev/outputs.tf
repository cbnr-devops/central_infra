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

variable "db_secret_name" {
  description = "Name of the Secrets Manager secret that holds DB credentials (username/password)"
  type        = string
  default     = "central-dev-db-credentials"
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.3"
}

variable "db_instance_class" {
  description = "Instance class for RDS PostgreSQL"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Database name to create"
  type        = string
  default     = "appdb"
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
  default     = 20
}

variable "db_deletion_protection" {
  description = "Enable deletion protection for RDS instance"
  type        = bool
  default     = false
}

variable "db_multi_az" {
  description = "Whether to use Multi-AZ deployment"
  type        = bool
  default     = false
}

output "cluster_oidc_issuer" {
  description = "OIDC issuer URL for dev EKS"
  value       = module.eks.cluster_oidc_issuer
}