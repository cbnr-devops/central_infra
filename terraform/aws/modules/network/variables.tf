variable "env" {
  description = "Environment name (e.g., shared, dev, staging)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
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
  description = "Availability Zones for the subnets"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT gateways for private subnets"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Base tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_nat_gateway" {
  type    = bool
  default = true
}