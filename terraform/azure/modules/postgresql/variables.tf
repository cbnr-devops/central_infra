variable "env" {
  description = "Environment name"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "admin_username" {
  description = "PostgreSQL administrator username"
  type        = string
}

variable "admin_password" {
  description = "PostgreSQL administrator password"
  type        = string
  sensitive   = true
}

variable "aks_subnet_cidr_start" {
  description = "Start IP of AKS subnet range for firewall rule"
  type        = string
}

variable "aks_subnet_cidr_end" {
  description = "End IP of AKS subnet range for firewall rule"
  type        = string
}

variable "sku_name" {
  description = "PostgreSQL SKU (compute tier)"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "storage_mb" {
  description = "Storage size in MB"
  type        = number
  default     = 32768
}

variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "16"
}