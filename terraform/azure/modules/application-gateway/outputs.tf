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
