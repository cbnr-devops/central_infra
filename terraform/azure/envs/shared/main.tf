module "resource_group" {
  source       = "../../modules/resource-group"
  env          = "shared"
  azure_region = var.location
}

data "azurerm_client_config" "current" {}

data "azurerm_virtual_network" "cicd" {
  name                = var.cicd_vnet_name
  resource_group_name = var.cicd_vnet_resource_group_name
}

data "azurerm_subnet" "cicd_private_endpoints" {
  name                 = var.cicd_private_endpoint_subnet_name
  virtual_network_name = data.azurerm_virtual_network.cicd.name
  resource_group_name  = var.cicd_vnet_resource_group_name
}

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

resource "azurerm_role_assignment" "pipeline_key_vault_secrets_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.pipeline_service_principal_object_id
}

module "acr" {
  source                     = "../../modules/acr"
  env                        = "shared"
  resource_group_name        = module.resource_group.name
  location                   = module.resource_group.location
  sku                        = "Premium"
  repositories               = var.acr_repositories
  enable_private_endpoint    = true
  vnet_id                    = data.azurerm_virtual_network.cicd.id
  private_endpoint_subnet_id = data.azurerm_subnet.cicd_private_endpoints.id
  allowed_ips                = var.agent_vm_ips
}

resource "azurerm_role_assignment" "pipeline_acr_push" {
  scope                = module.acr.acr_id
  role_definition_name = "AcrPush"
  principal_id         = var.pipeline_service_principal_object_id
  principal_type       = "ServicePrincipal"
}
