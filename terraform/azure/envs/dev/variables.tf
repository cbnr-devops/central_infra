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

variable "env" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "australiaeast"
}

variable "management_operator_object_id" {
  description = "Microsoft Entra object ID granted administrator login to the management VM"
  type        = string
}

variable "management_admin_ssh_public_key" {
  description = "SSH public key for the management VM break-glass administrator"
  type        = string
}
