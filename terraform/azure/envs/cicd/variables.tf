variable "location" {
  description = "Azure region for the CI/CD infrastructure and Managed DevOps Pool."
  type        = string
  default     = "australiaeast"
}

variable "resource_group_name" {
  description = "Resource group for the CI/CD infrastructure."
  type        = string
  default     = "central-infra-cicd-rg"
}

variable "vnet_name" {
  description = "Name of the dedicated CI/CD virtual network."
  type        = string
  default     = "central-cicd-vnet"
}

variable "vnet_cidr" {
  description = "Address space for the dedicated CI/CD virtual network."
  type        = string
  default     = "10.10.0.0/16"
}

variable "agent_subnet_cidr" {
  description = "Address prefix for the Managed DevOps Pool delegated subnet."
  type        = string
  default     = "10.10.1.0/27"
}

variable "private_endpoint_subnet_cidr" {
  description = "Address prefix reserved for CI/CD private endpoints."
  type        = string
  default     = "10.10.2.0/27"
}

variable "azure_devops_organization_url" {
  description = "Azure DevOps organization URL, for example https://dev.azure.com/example."
  type        = string

  validation {
    condition     = can(regex("^https://dev\\.azure\\.com/[A-Za-z0-9._-]+/?$", var.azure_devops_organization_url))
    error_message = "The organization URL must use the form https://dev.azure.com/<organization>."
  }
}

variable "azure_devops_project_name" {
  description = "Azure DevOps project in which the Managed DevOps Pool will be available."
  type        = string
}

variable "managed_devops_pool_name" {
  description = "Globally unique name for the Managed DevOps Pool Azure resource."
  type        = string
  default     = "central-infra-mdp"
}

variable "maximum_concurrency" {
  description = "Maximum number of Managed DevOps Pool agents that can run concurrently."
  type        = number
  default     = 1

  validation {
    condition     = var.maximum_concurrency >= 1 && var.maximum_concurrency <= 10000
    error_message = "Maximum concurrency must be between 1 and 10000."
  }
}

variable "agent_vm_size" {
  description = "Azure VM SKU used by the Managed DevOps Pool agents."
  type        = string
  default     = "Standard_D2ads_v5"
}

variable "gallery_image_definition_id" {
  description = "Resource ID of the existing Azure Compute Gallery image definition used by the Managed DevOps Pool."
  type        = string

  validation {
    condition     = can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Compute/galleries/[^/]+/images/[^/]+$", var.gallery_image_definition_id))
    error_message = "The value must be an Azure Compute Gallery image definition ID ending in /images/<image-name>, not an image version ID."
  }
}

variable "custom_image_alias" {
  description = "Alias exposed by the pool for the custom image."
  type        = string
  default     = "central-custom-linux"
}

variable "tags" {
  description = "Tags applied to CI/CD resources."
  type        = map(string)
  default = {
    Environment = "cicd"
    ManagedBy   = "Terraform"
    Project     = "central-infra"
  }
}
