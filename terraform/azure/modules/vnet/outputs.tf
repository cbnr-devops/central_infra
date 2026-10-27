output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "vnet_name" {
  value = azurerm_virtual_network.this.name
}

output "private_subnet_id" {
  value = azurerm_subnet.private.id

  depends_on = [azurerm_subnet_nat_gateway_association.private]
}

output "public_subnet_id" {
  value = azurerm_subnet.public.id
}

output "private_endpoint_subnet_id" {
  value = azurerm_subnet.private_endpoint.id
}

output "application_gateway_subnet_id" {
  description = "Resource ID of the dedicated Application Gateway subnet"
  value       = azurerm_subnet.application_gateway.id
}

output "application_gateway_private_link_subnet_id" {
  description = "Resource ID of the subnet reserved for Application Gateway Private Link configuration IPs"
  value       = azurerm_subnet.application_gateway_private_link.id
}

output "nat_public_ip_address" {
  description = "Public egress IP address of the environment NAT Gateway"
  value       = azurerm_public_ip.nat.ip_address
}

output "nat_gateway_id" {
  description = "Resource ID of the environment NAT Gateway"
  value       = azurerm_nat_gateway.this.id
}
