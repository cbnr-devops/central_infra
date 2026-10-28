variable "location" {
  description = "Azure region"
  type        = string
  default     = "australiaeast"
}

variable "key_vault_name" {
  description = "Shared Key Vault name used by dev/staging"
  type        = string
  default     = "skssecrets"
}

variable "acr_repositories" {
  description = "List of repository names to create in ACR"
  type        = list(string)
  default     = ["solar-system", "starship-fleet"]
}

variable "agent_vm_ips" {
  description = "Temporary public IP allowlist retained during the ACR private endpoint cutover; set to an empty list after private connectivity is verified"
  type        = list(string)
  default     = []
}

variable "pipeline_service_principal_object_id" {
  description = "Microsoft Entra object ID of the Azure DevOps service connection principal"
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.pipeline_service_principal_object_id))
    error_message = "pipeline_service_principal_object_id must be a UUID-formatted Microsoft Entra object ID."
  }
}

variable "cicd_vnet_resource_group_name" {
  description = "Resource group containing the Managed DevOps Pool VNet"
  type        = string
  default     = "central-infra-cicd-rg"
}

variable "cicd_vnet_name" {
  description = "VNet used by the Managed DevOps Pool"
  type        = string
  default     = "central-cicd-vnet"
}

variable "cicd_private_endpoint_subnet_name" {
  description = "Subnet in the CI/CD VNet reserved for private endpoints"
  type        = string
  default     = "private-endpoints-subnet"
}
