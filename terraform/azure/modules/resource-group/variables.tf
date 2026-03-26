variable "env" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "azure_region" {
  description = "Azure region"
  type        = string
  default     = "australiaeast"
}
