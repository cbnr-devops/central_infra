module "resource_group" {
  source       = "../../modules/resource-group"
  env          = "dev"
  azure_region = var.azure_region
}

module "vnet" {
  source              = "../../modules/vnet"
  env                 = "dev"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  vnet_cidr           = var.vnet_cidr
}

module "aks" {
  source              = "../../modules/aks"
  env                 = "dev"
  cluster_name        = "dev-cluster"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  subnet_id           = module.vnet.private_subnet_id
  vm_size             = var.vm_size
  max_pods            = 100
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.this.id
}

module "postgresql" {
  source              = "../../modules/postgresql"
  env                 = "dev"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  admin_username      = data.azurerm_key_vault_secret.pg_username.value
  admin_password      = data.azurerm_key_vault_secret.pg_password.value  
  private_endpoint_subnet_id = module.vnet.private_endpoint_subnet_id
  vnet_id                    = module.vnet.vnet_id
}


data "azurerm_key_vault" "this" {
  name                = "skssolarsecrets"
  resource_group_name = "VisualStudioOnline-696441FDFCD6415E97BD6B658AFB5291"
}

data "azurerm_key_vault_secret" "pg_password" {
  name         = "postgres-password"
  key_vault_id = data.azurerm_key_vault.this.id
}

data "azurerm_key_vault_secret" "pg_username" {
  name         = "postgres-username"
  key_vault_id = data.azurerm_key_vault.this.id
}

data "azurerm_log_analytics_workspace" "this" {
  name                = "central-logs-workspace"   
  resource_group_name = "central-monitoring-rg"     
}