output "resource_group_name" {
  value = module.resource_group.name
}

output "resource_group_location" {
  value = module.resource_group.location
}

output "grafana_endpoint" {
  value = module.monitoring.grafana_endpoint
}

output "external_secrets_identity_client_id" {
  description = "Client ID to use in the azure-keyvault-reader Kubernetes service account annotation"
  value       = azurerm_user_assigned_identity.external_secrets.client_id
}

output "external_secrets_identity_principal_id" {
  description = "Principal ID granted Key Vault Secrets User on the shared Key Vault"
  value       = azurerm_user_assigned_identity.external_secrets.principal_id
}
