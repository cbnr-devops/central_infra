output "bastion_name" {
  description = "Name of the Azure Bastion host"
  value       = azurerm_bastion_host.this.name
}

output "bastion_id" {
  description = "Resource ID of the Azure Bastion host"
  value       = azurerm_bastion_host.this.id
}

output "management_vm_id" {
  description = "Resource ID of the management VM"
  value       = azurerm_linux_virtual_machine.management.id
}

output "management_vm_private_ip" {
  description = "Private IP address of the management VM"
  value       = azurerm_network_interface.management.private_ip_address
}
