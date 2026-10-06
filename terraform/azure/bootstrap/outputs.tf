output "resource_group_name" {
  description = "Resource group containing the Terraform backend."
  value       = azurerm_resource_group.terraform_state.name
}

output "storage_account_name" {
  description = "Storage account containing the Terraform state containers."
  value       = azurerm_storage_account.terraform_state.name
}

output "storage_account_id" {
  description = "Resource ID of the Terraform state storage account."
  value       = azurerm_storage_account.terraform_state.id
}

output "state_containers" {
  description = "Terraform state containers created by the bootstrap root."
  value       = sort(tolist(var.state_containers))
}

output "configured_resource_providers" {
  description = "Azure resource providers the AzureRM provider ensures are registered."
  value       = sort(tolist(var.resource_providers))
}
