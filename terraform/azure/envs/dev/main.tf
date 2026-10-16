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
  api_server_authorized_ip_ranges = [
    "${data.azurerm_public_ip.cicd_nat.ip_address}/32",
    "${module.vnet.nat_public_ip_address}/32",
  ]
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                            = data.azurerm_container_registry.shared.id
  role_definition_name             = "AcrPull"
  principal_id                     = module.aks.kubelet_identity_object_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_user_assigned_identity" "external_secrets" {
  name                = "dev-external-secrets"
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name

  tags = {
    Environment = "dev"
    Project     = "central-infra"
  }
}

resource "azurerm_role_assignment" "external_secrets_key_vault_reader" {
  scope                            = data.azurerm_key_vault.this.id
  role_definition_name             = "Key Vault Secrets User"
  principal_id                     = azurerm_user_assigned_identity.external_secrets.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_federated_identity_credential" "external_secrets" {
  name                      = "dev-external-secrets"
  user_assigned_identity_id = azurerm_user_assigned_identity.external_secrets.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = module.aks.oidc_issuer_url
  subject                   = "system:serviceaccount:dev:azure-keyvault-reader"
}

module "postgresql" {
  source                     = "../../modules/postgresql"
  env                        = "dev"
  resource_group_name        = module.resource_group.name
  location                   = module.resource_group.location
  admin_username             = data.azurerm_key_vault_secret.pg_username.value
  admin_password             = data.azurerm_key_vault_secret.pg_password.value
  private_endpoint_subnet_id = module.vnet.private_endpoint_subnet_id
  vnet_id                    = module.vnet.vnet_id
}

module "monitoring" {
  source              = "../../modules/monitoring"
  env                 = "dev"
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
  name                = "skssecrets"
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

data "azurerm_public_ip" "cicd_nat" {
  name                = "central-cicd-nat-pip"
  resource_group_name = "central-infra-cicd-rg"
}
