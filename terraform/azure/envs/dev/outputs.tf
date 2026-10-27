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

output "bastion_name" {
  description = "Name of the Azure Bastion host used for native management access"
  value       = module.management_host.bastion_name
}

output "management_vm_id" {
  description = "Resource ID used with az network bastion ssh"
  value       = module.management_host.management_vm_id
}

output "management_vm_private_ip" {
  description = "Private IP address of the management VM"
  value       = module.management_host.management_vm_private_ip
}

output "application_gateway_id" {
  description = "Resource ID of the regional AKS ingress gateway"
  value       = module.application_gateway.id
}

output "application_gateway_name" {
  description = "Name of the regional AKS ingress gateway"
  value       = module.application_gateway.name
}

output "application_gateway_private_ip" {
  description = "Private frontend address to use when validating ingress routing"
  value       = module.application_gateway.private_ip_address
}

output "agic_identity_object_id" {
  description = "Managed identity object ID used by the AKS AGIC add-on"
  value       = module.aks.agic_identity_object_id
}
