resource "azurerm_storage_account" "this" {
  name                     = "central${var.env}storage"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type

  tags = {
    Environment = var.env
    Project     = "central-infra"
  }
}

resource "azurerm_storage_container" "this" {
  for_each = toset(var.containers)

  name                  = each.value
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = "private"
}
