variable "env" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for dev environment"
  type        = string
  default     = "ap-southeast-2"
}

variable "vpc_cidr" {
  description = "CIDR block for the dev VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "azs" {
  description = "Availability zones for dev subnets (EKS and RDS require at least two)"
  type        = list(string)
  default     = ["ap-southeast-2a", "ap-southeast-2b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.1.0.0/24", "10.1.1.0/24"]
}

variable "eks_subnet_cidr" {
  description = "CIDR for the EKS (private) subnet"
  type        = string
  default     = "10.1.10.0/24"
}

variable "db_subnet_cidr" {
  description = "CIDR for the DB subnet"
  type        = string
  default     = "10.1.20.0/24"
}

variable "db_secret_name" {
  description = "Name of the Secrets Manager secret that holds DB credentials (username/password)"
  type        = string
  default     = "central-dev-db-credentials"
}

variable "db_engine_version" {
  description = "PostgreSQL major engine version (e.g. \"16\"); AWS picks the latest available minor in the region"
  type        = string
  default     = "16"
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

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "dev-cluster"
}

variable "eks_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.30"
}

variable "eks_node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default     = "m7i-flex.large"
}

variable "eks_node_desired_size" {
  description = "Desired number of nodes in the node group"
  type        = number
  default     = 2
}

variable "eks_node_min_size" {
  description = "Minimum number of nodes in the node group"
  type        = number
  default     = 2
}

variable "eks_node_max_size" {
  description = "Maximum number of nodes in the node group"
  type        = number
  default     = 2
}

variable "irsa_sa_namespace" {
  description = "Kubernetes namespace of the service account that will use IRSA (ESO)"
  type        = string
  default     = "external-secrets"
}

variable "irsa_sa_name" {
  description = "Kubernetes service account name that will use IRSA (ESO)"
  type        = string
  default     = "external-secrets"
}
