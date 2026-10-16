output "vnet_id" {
  value = azurerm_virtual_network.this.id
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

output "nat_public_ip_address" {
  description = "Public egress IP address of the environment NAT Gateway"
  value       = azurerm_public_ip.nat.ip_address
}
