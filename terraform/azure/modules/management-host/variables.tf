variable "name_prefix" {
  description = "Name prefix for the Bastion and management host resources"
  type        = string
}

variable "location" {
  description = "Azure region in which to deploy the resources"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group containing the target virtual network"
  type        = string
}

variable "virtual_network_name" {
  description = "Name of the virtual network that hosts Bastion and the management VM"
  type        = string
}

variable "nat_gateway_id" {
  description = "NAT Gateway used for management-host outbound connectivity"
  type        = string
}

variable "bastion_subnet_cidr" {
  description = "CIDR for the dedicated AzureBastionSubnet; must be /26 or larger"
  type        = string
}

variable "management_subnet_cidr" {
  description = "CIDR for the private management-host subnet"
  type        = string
}

variable "operator_object_id" {
  description = "Microsoft Entra object ID granted administrator login to the management VM"
  type        = string
}

variable "admin_username" {
  description = "Break-glass local administrator account name"
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "SSH public key for the break-glass local administrator account"
  type        = string
}

variable "vm_size" {
  description = "Size of the management VM"
  type        = string
  default     = "Standard_B2als_v2"
}

variable "tags" {
  description = "Tags applied to management resources"
  type        = map(string)
  default     = {}
}
