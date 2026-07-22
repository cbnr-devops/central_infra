module "resource_group" {
  source       = "../../modules/resource-group"
  env          = "shared"
  azure_region = var.location
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "this" {
  name                          = var.key_vault_name
  location                      = module.resource_group.location
  resource_group_name           = module.resource_group.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  soft_delete_retention_days    = 7
  purge_protection_enabled      = true
  public_network_access_enabled = true
  rbac_authorization_enabled    = true

  tags = {
    Environment = "shared"
    Project     = "central-infra"
  }
}

module "acr" {
  source                  = "../../modules/acr"
  env                     = "shared"
  resource_group_name     = module.resource_group.name
  location                = module.resource_group.location
  sku                     = "Premium"
  repositories            = var.acr_repositories
  enable_private_endpoint = false
  allowed_ips             = var.agent_vm_ips
}