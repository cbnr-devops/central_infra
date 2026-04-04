variable "azure_region" {
  description = "Azure region"
  type        = string
  default     = "australiaeast"
}

variable "vnet_cidr" {
  description = "CIDR block for VNet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vm_size" {
  description = "AKS node VM size"
  type        = string
  default     = "Standard_B4als_v2"
}

variable "pg_admin_username" {
  description = "PostgreSQL administrator username"
  type        = string
}

variable "pg_admin_password" {
  description = "PostgreSQL administrator password"
  type        = string
  sensitive   = true
}

variable "aks_subnet_cidr_start" {
  description = "Start IP of AKS subnet for PostgreSQL firewall"
  type        = string
}

variable "aks_subnet_cidr_end" {
  description = "End IP of AKS subnet for PostgreSQL firewall"
  type        = string
}
