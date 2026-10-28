variable "location" {
  description = "Azure region for the Terraform backend resources."
  type        = string
  default     = "australiaeast"
}

variable "resource_group_name" {
  description = "Resource group dedicated to Terraform state infrastructure."
  type        = string
  default     = "central-infra-tf-state-rg"
}

variable "storage_account_name" {
  description = "Globally unique storage account name for Terraform state."
  type        = string
  default     = "sksinfratfstate"

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "The storage account name must contain 3-24 lowercase letters or numbers."
  }
}

variable "state_containers" {
  description = "Blob containers used by the Azure Terraform environment roots."
  type        = set(string)
  default = [
    "cicd-tfstate",
    "dev-tfstate",
    "shared-tfstate",
    "staging-tfstate",
  ]
}

variable "resource_providers" {
  description = "Azure resource providers the AzureRM provider ensures are registered."
  type        = set(string)
  default = [
    "Microsoft.Authorization",
    "Microsoft.Compute",
    "Microsoft.ContainerRegistry",
    "Microsoft.ContainerService",
    "Microsoft.DBforPostgreSQL",
    "Microsoft.DevCenter",
    "Microsoft.DevOpsInfrastructure",
    "microsoft.insights",
    "Microsoft.KeyVault",
    "Microsoft.ManagedIdentity",
    "Microsoft.Network",
    "Microsoft.OperationalInsights",
    "Microsoft.Storage",
  ]
}

variable "tags" {
  description = "Tags applied to the Terraform backend resources."
  type        = map(string)
  default = {
    Environment = "bootstrap"
    ManagedBy   = "Terraform"
    Project     = "central-infra"
  }
}
