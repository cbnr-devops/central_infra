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

variable "pipeline_service_principal_object_id" {
  description = "Microsoft Entra object ID of the Azure DevOps service connection principal"
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.pipeline_service_principal_object_id))
    error_message = "pipeline_service_principal_object_id must be a UUID-formatted Microsoft Entra object ID."
  }
}

variable "management_admin_ssh_public_key" {
  description = "SSH public key for the management VM break-glass administrator"
  type        = string
}
