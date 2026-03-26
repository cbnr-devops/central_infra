output "acr_id" {
  description = "The ID of the container registry"
  value       = azurerm_container_registry.this.id
}

output "acr_login_server" {
  description = "The login server URL of the container registry"
  value       = azurerm_container_registry.this.login_server
}

output "acr_name" {
  description = "The name of the container registry"
  value       = azurerm_container_registry.this.name
}
