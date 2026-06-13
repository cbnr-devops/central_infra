variable "env" {
  description = "Environment name (e.g., dev, staging)"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where EKS will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for worker nodes and control plane ENIs"
  type        = list(string)
}

variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "instance_type" {
  description = "Worker node instance type"
  type        = string
  default     = "t3.medium"
}

variable "desired_capacity" {
  description = "Desired node count"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum node count"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum node count"
  type        = number
  default     = 4
}

variable "tags" {
  description = "Additional tags to apply"
  type        = map(string)
  default     = {}
}