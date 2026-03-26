resource "azurerm_container_registry" "this" {
  name                = "central${var.env}acr"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = false

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
