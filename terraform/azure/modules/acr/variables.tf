variable "env" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "sku" {
  description = "SKU for the container registry"
  type        = string
  default     = "Premium"
}

variable "repositories" {
  description = "List of repository names to create in the ACR"
  type        = list(string)
}

variable "enable_private_endpoint" {
  description = "Whether to create a private endpoint for ACR"
  type        = bool
  default     = false
}

variable "vnet_id" {
  description = "VNet ID to link the private DNS zone to"
  type        = string
  default     = null
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID where the private endpoint NIC will be created"
  type        = string
  default     = null
}

variable "allowed_ips" {
  description = "List of public IP addresses or CIDR ranges allowed to access ACR (e.g. build agent IPs)"
  type        = list(string)
  default     = []
}
