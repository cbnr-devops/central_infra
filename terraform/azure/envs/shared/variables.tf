variable "location" {
  description = "Azure region"
  type        = string
  default     = "australiaeast"
}

variable "key_vault_name" {
  description = "Shared Key Vault name used by dev/staging"
  type        = string
  default     = "skssolarsecrets"
}

variable "acr_repositories" {
  description = "List of repository names to create in ACR"
  type        = list(string)
  default     = ["solar-system", "starship-fleet"]
}

variable "agent_vm_ips" {
  description = "Public IPs of build agent VMs to whitelist on ACR"
  type        = list(string)
  default     = []
}

variable "dev_vnet_resource_group_name" {
  description = "Resource group where the dev VNet (and PE subnet) live"
  type        = string
  default     = "central-dev-rg"
}

variable "dev_vnet_name" {
  description = "Name of the dev VNet that hosts the private endpoint subnet"
  type        = string
  default     = "central-dev-vnet"
}

variable "dev_private_endpoint_subnet_name" {
  description = "Subnet name for ACR private endpoint NIC (from vnet module)"
  type        = string
  default     = "dev-pe-subnet"
}