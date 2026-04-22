variable "azure_region" {
  description = "Azure region"
  type        = string
  default     = "australiaeast"
}

variable "vnet_cidr" {
  description = "CIDR block for VNet"
  type        = string
  default     = "10.1.0.0/16"
}

variable "vm_size" {
  description = "AKS node VM size"
  type        = string
  default     = "Standard_B4als_v2"
}

variable "env" {
  description = "Environment name"
  type        = string
  default     = "staging"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "australiaeast"
}