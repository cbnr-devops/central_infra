output "id" {
  description = "Resource ID of Application Gateway"
  value       = azurerm_application_gateway.this.id
}

output "name" {
  description = "Name of Application Gateway"
  value       = azurerm_application_gateway.this.name
}

output "private_ip_address" {
  description = "Private frontend IP address used by the AKS ingress"
  value       = var.private_ip_address
}

output "private_frontend_ip_configuration_name" {
  description = "Frontend IP configuration exposed through Application Gateway Private Link"
  value       = local.frontend_ip_configuration
}
