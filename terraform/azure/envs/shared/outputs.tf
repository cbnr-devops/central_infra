output "acr_login_server" {
  description = "ACR login server hostname"
  value       = module.acr.acr_login_server
}

output "acr_id" {
  description = "ACR resource ID"
  value       = module.acr.acr_id
}

output "acr_private_endpoint_ip" {
  description = "Private IP of the ACR private endpoint"
  value       = module.acr.private_endpoint_ip
}

output "key_vault_name" {
  description = "Shared Key Vault name"
  value       = azurerm_key_vault.this.name
}

output "key_vault_id" {
  description = "Shared Key Vault resource ID"
  value       = azurerm_key_vault.this.id
}
