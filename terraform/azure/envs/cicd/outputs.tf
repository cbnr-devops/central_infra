output "managed_devops_pool_id" {
  description = "Resource ID of the Managed DevOps Pool."
  value       = azurerm_managed_devops_pool.cicd.id
}

output "managed_devops_pool_name" {
  description = "Name used to select the pool in Azure Pipelines YAML."
  value       = azurerm_managed_devops_pool.cicd.name
}

output "dev_center_id" {
  description = "Resource ID of the CI/CD Dev Center."
  value       = azurerm_dev_center.cicd.id
}

output "dev_center_project_id" {
  description = "Resource ID of the CI/CD Dev Center project."
  value       = azurerm_dev_center_project.cicd.id
}

output "vnet_id" {
  description = "Resource ID of the CI/CD virtual network."
  value       = azurerm_virtual_network.cicd.id
}

output "managed_devops_pool_subnet_id" {
  description = "Resource ID of the subnet delegated to Managed DevOps Pools."
  value       = azurerm_subnet.managed_devops_pool.id
}

output "private_endpoint_subnet_id" {
  description = "Resource ID of the subnet reserved for CI/CD private endpoints."
  value       = azurerm_subnet.private_endpoints.id
}

output "nat_gateway_public_ip" {
  description = "Stable public egress IP used by Managed DevOps Pool agents."
  value       = azurerm_public_ip.nat_gateway.ip_address
}

output "devops_infrastructure_principal_id" {
  description = "Tenant-specific object ID of the DevOpsInfrastructure service principal."
  value       = data.azuread_service_principal.devops_infrastructure.object_id
}

output "gallery_image_definition_id" {
  description = "Existing image definition ID supplied to the Managed DevOps Pool."
  value       = var.gallery_image_definition_id
}
