variable "aws_region" {
  description = "AWS region for the shared environment"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the shared VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
}

variable "azs" {
  description = "Availability Zones to use"
  type        = list(string)
}

variable "ecr_repositories" {
  description = "List of ECR repositories to create in shared env"
  type        = list(string)
}