resource "azurerm_container_registry" "this" {
  name                = "skssolar"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = false

  public_network_access_enabled = var.enable_private_endpoint ? false : true
  network_rule_bypass_option    = var.enable_private_endpoint ? "AzureServices" : null

  tags = {
    Environment = var.env
    Project     = "central-infra"
  }
}

resource "azurerm_container_registry_scope_map" "repos" {
  for_each = toset(var.repositories)

  name                    = "${each.value}-scope"
  container_registry_name = azurerm_container_registry.this.name
  resource_group_name     = var.resource_group_name

  actions = [
    "repositories/${each.value}/content/read",
    "repositories/${each.value}/content/write",
    "repositories/${each.value}/content/delete",
  ]
}

resource "azurerm_private_endpoint" "acr" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "pe-central-${var.env}-acr"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "psc-central-${var.env}-acr"
    private_connection_resource_id = azurerm_container_registry.this.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "acr-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr[0].id]
  }

  tags = {
    Environment = var.env
    Project     = "central-infra"
  }
}

resource "azurerm_private_dns_zone" "acr" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "privatelink.azurecr.io"
  resource_group_name = var.resource_group_name

  tags = {
    Environment = var.env
    Project     = "central-infra"
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  count                 = var.enable_private_endpoint ? 1 : 0
  name                  = "link-acr-${var.env}-vnet"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.acr[0].name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false

  tags = {
    Environment = var.env
    Project     = "central-infra"
  }
}


