data "azuread_service_principal" "devops_infrastructure" {
  display_name = "DevOpsInfrastructure"
}

resource "azurerm_resource_group" "cicd" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "cicd" {
  name                = var.vnet_name
  location            = azurerm_resource_group.cicd.location
  resource_group_name = azurerm_resource_group.cicd.name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "managed_devops_pool" {
  name                            = "managed-devops-pool-subnet"
  resource_group_name             = azurerm_resource_group.cicd.name
  virtual_network_name            = azurerm_virtual_network.cicd.name
  address_prefixes                = [var.agent_subnet_cidr]
  default_outbound_access_enabled = false

  delegation {
    name = "managed-devops-pool-delegation"

    service_delegation {
      name = "Microsoft.DevOpsInfrastructure/pools"
    }
  }
}

resource "azurerm_subnet" "private_endpoints" {
  name                              = "private-endpoints-subnet"
  resource_group_name               = azurerm_resource_group.cicd.name
  virtual_network_name              = azurerm_virtual_network.cicd.name
  address_prefixes                  = [var.private_endpoint_subnet_cidr]
  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_public_ip" "nat_gateway" {
  name                = "central-cicd-nat-pip"
  location            = azurerm_resource_group.cicd.location
  resource_group_name = azurerm_resource_group.cicd.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "cicd" {
  name                    = "central-cicd-natgw"
  location                = azurerm_resource_group.cicd.location
  resource_group_name     = azurerm_resource_group.cicd.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  tags                    = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "cicd" {
  nat_gateway_id       = azurerm_nat_gateway.cicd.id
  public_ip_address_id = azurerm_public_ip.nat_gateway.id
}

resource "azurerm_subnet_nat_gateway_association" "managed_devops_pool" {
  subnet_id      = azurerm_subnet.managed_devops_pool.id
  nat_gateway_id = azurerm_nat_gateway.cicd.id
}

resource "azurerm_role_assignment" "devops_infrastructure_vnet_reader" {
  scope                = azurerm_virtual_network.cicd.id
  role_definition_name = "Reader"
  principal_id         = data.azuread_service_principal.devops_infrastructure.object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "devops_infrastructure_vnet_network_contributor" {
  scope                = azurerm_virtual_network.cicd.id
  role_definition_name = "Network Contributor"
  principal_id         = data.azuread_service_principal.devops_infrastructure.object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "devops_infrastructure_image_reader" {
  scope                = var.compute_gallery_id
  role_definition_name = "Compute Gallery Image Reader"
  principal_id         = data.azuread_service_principal.devops_infrastructure.object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_dev_center" "cicd" {
  name                = "central-cicd-devcenter"
  resource_group_name = azurerm_resource_group.cicd.name
  location            = azurerm_resource_group.cicd.location
  tags                = var.tags
}

resource "azurerm_dev_center_project" "cicd" {
  name                = "central-cicd-project"
  resource_group_name = azurerm_resource_group.cicd.name
  location            = azurerm_resource_group.cicd.location
  dev_center_id       = azurerm_dev_center.cicd.id
  tags                = var.tags
}

resource "azurerm_managed_devops_pool" "cicd" {
  name                  = var.managed_devops_pool_name
  resource_group_name   = azurerm_resource_group.cicd.name
  location              = azurerm_resource_group.cicd.location
  dev_center_project_id = azurerm_dev_center_project.cicd.id
  maximum_concurrency   = var.maximum_concurrency

  azure_devops_organization {
    organization {
      url         = trimsuffix(var.azure_devops_organization_url, "/")
      projects    = [var.azure_devops_project_name]
      parallelism = var.maximum_concurrency
    }
  }

  stateless_agent {}

  virtual_machine_scale_set_fabric {
    sku_name  = var.agent_vm_size
    subnet_id = azurerm_subnet.managed_devops_pool.id

    image {
      id      = var.gallery_image_definition_id
      aliases = [var.custom_image_alias]
      buffer  = "*"
    }
  }

  tags = var.tags

  depends_on = [
    azurerm_role_assignment.devops_infrastructure_image_reader,
    azurerm_role_assignment.devops_infrastructure_vnet_network_contributor,
    azurerm_role_assignment.devops_infrastructure_vnet_reader,
    azurerm_subnet_nat_gateway_association.managed_devops_pool,
  ]
}
