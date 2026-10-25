resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.virtual_network_name
  address_prefixes     = [var.bastion_subnet_cidr]
}

resource "azurerm_subnet" "management" {
  name                            = "management-subnet"
  resource_group_name             = var.resource_group_name
  virtual_network_name            = var.virtual_network_name
  address_prefixes                = [var.management_subnet_cidr]
  default_outbound_access_enabled = false
}

resource "azurerm_subnet_nat_gateway_association" "management" {
  subnet_id      = azurerm_subnet.management.id
  nat_gateway_id = var.nat_gateway_id
}

resource "azurerm_network_security_group" "management" {
  name                = "${var.name_prefix}-management-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "AllowSshFromAzureBastion"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.bastion_subnet_cidr
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "management" {
  subnet_id                 = azurerm_subnet.management.id
  network_security_group_id = azurerm_network_security_group.management.id
}

resource "azurerm_public_ip" "bastion" {
  name                = "${var.name_prefix}-bastion-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

resource "azurerm_bastion_host" "this" {
  name                = "${var.name_prefix}-bastion"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"

  copy_paste_enabled = true
  file_copy_enabled  = true
  tunneling_enabled  = true

  ip_configuration {
    name                 = "bastion-ip-configuration"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  tags = var.tags
}

resource "azurerm_network_interface" "management" {
  name                = "${var.name_prefix}-management-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "management-ip-configuration"
    subnet_id                     = azurerm_subnet.management.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags

  depends_on = [
    azurerm_subnet_nat_gateway_association.management,
    azurerm_subnet_network_security_group_association.management,
  ]
}

resource "azurerm_linux_virtual_machine" "management" {
  name                = "${var.name_prefix}-management-vm"
  computer_name       = "dev-management"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  admin_username      = var.admin_username

  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.management.id]
  custom_data                     = filebase64("${path.module}/cloud-init.yaml")

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    name                 = "${var.name_prefix}-management-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {}

  tags = var.tags
}

resource "azurerm_virtual_machine_extension" "entra_ssh" {
  name                       = "AADSSHLoginForLinux"
  virtual_machine_id         = azurerm_linux_virtual_machine.management.id
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADSSHLoginForLinux"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}

resource "azurerm_role_assignment" "operator_vm_admin" {
  scope                = azurerm_linux_virtual_machine.management.id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id         = var.operator_object_id
  principal_type       = "User"
}
