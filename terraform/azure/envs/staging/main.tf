module "resource_group" {
  source       = "../../modules/resource-group"
  env          = "staging"
  azure_region = var.azure_region
}

module "vnet" {
  source              = "../../modules/vnet"
  env                 = "staging"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  vnet_cidr           = var.vnet_cidr
}

module "aks" {
  source              = "../../modules/aks"
  env                 = "staging"
  cluster_name        = "staging-cluster"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  subnet_id           = module.vnet.private_subnet_id
  vm_size             = var.vm_size
  max_pods            = 100
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.this.id
}

module "postgresql" {
  source              = "../../modules/postgresql"
  env                 = "staging"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  admin_username      = data.azurerm_key_vault_secret.pg_username.value
  admin_password      = data.azurerm_key_vault_secret.pg_password.value  
  private_endpoint_subnet_id = module.vnet.private_endpoint_subnet_id
  vnet_id                    = module.vnet.vnet_id
}

module "monitoring" {
  source              = "../../modules/monitoring"
  env                 = "staging"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  aks_cluster_id      = module.aks.cluster_id
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "central-${var.env}-logs"
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_private_dns_zone" "acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = module.resource_group.name

  tags = {
    Environment = "dev"
    Project     = "central-infra"
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  name                  = "link-acr-dev-vnet"
  resource_group_name   = module.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = module.vnet.vnet_id
  registration_enabled  = false

  tags = {
    Environment = "dev"
    Project     = "central-infra"
  }
}

resource "azurerm_private_endpoint" "acr" {
  name                = "pe-central-dev-acr"
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  subnet_id           = module.vnet.private_endpoint_subnet_id

  private_service_connection {
    name                           = "psc-central-dev-acr"
    private_connection_resource_id = data.azurerm_container_registry.shared.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "acr-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr.id]
  }

  tags = {
    Environment = "dev"
    Project     = "central-infra"
  }
}

data "azurerm_key_vault" "this" {
  name                = "skssolarsecrets"
  resource_group_name = "central-shared-rg"
}

data "azurerm_key_vault_secret" "pg_password" {
  name         = "postgres-password"
  key_vault_id = data.azurerm_key_vault.this.id
}

data "azurerm_key_vault_secret" "pg_username" {
  name         = "postgres-username"
  key_vault_id = data.azurerm_key_vault.this.id
}

data "azurerm_container_registry" "shared" {
  name                = "skssolar"
  resource_group_name = "central-shared-rg"
}