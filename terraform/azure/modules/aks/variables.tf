variable "env" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
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

variable "subnet_id" {
  description = "Subnet ID for the AKS node pool"
  type        = string
}

variable "vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_B4als_v2"
}

variable "max_pods" {
  description = "Maximum number of pods per node"
  type        = number
  default     = 100
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for AMA/OMS agent"
  type        = string
}

variable "api_server_authorized_ip_ranges" {
  description = "CIDR ranges allowed to access the public AKS API server"
  type        = list(string)
  default     = []
}

variable "application_gateway_id" {
  description = "Existing Application Gateway resource ID managed by the AKS AGIC add-on"
  type        = string
  default     = null
}
