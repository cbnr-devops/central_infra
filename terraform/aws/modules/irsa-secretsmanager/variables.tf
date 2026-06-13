variable "env" {
  description = "Environment name (e.g., dev, staging)"
  type        = string
}

variable "cluster_oidc_issuer" {
  description = "EKS cluster OIDC issuer URL (from aws_eks_cluster.identity[0].oidc[0].issuer)"
  type        = string
}

variable "service_account_namespace" {
  description = "Kubernetes namespace of the service account"
  type        = string
}

variable "service_account_name" {
  description = "Kubernetes service account name"
  type        = string
}

variable "secret_arns" {
  description = "List of Secrets Manager secret ARNs this role may read"
  type        = list(string)
}

variable "tags" {
  description = "Additional tags to apply"
  type        = map(string)
  default     = {}
}