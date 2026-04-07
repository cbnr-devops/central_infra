resource "azurerm_postgresql_flexible_server" "this" {
  name                   = "${var.env}-solar-postgres"
  resource_group_name    = var.resource_group_name
  location               = var.location
  version                = "16"
  administrator_login    = var.admin_username
  administrator_password = var.admin_password
  zone                   = "1"

  sku_name   = "B_Standard_B1ms" 
  storage_mb = 32768               

  backup_retention_days = 7
  tags = {
    Environment = var.env
  }

  public_network_access_enabled = false
}

resource "azurerm_postgresql_flexible_server_database" "planets" {
  name      = "planets"
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "aks" {
  name      = "allow-aks"
  server_id = azurerm_postgresql_flexible_server.this.id
  start_ip_address = var.aks_subnet_cidr_start
  end_ip_address   = var.aks_subnet_cidr_end
}

resource "azurerm_private_endpoint" "postgresql" {
  name                = "${var.env}-postgresql-pe"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.env}-postgresql-psc"
    private_connection_resource_id = azurerm_postgresql_flexible_server.this.id
    subresource_names              = ["postgresqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "postgresql-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.postgresql.id]
  }
}

resource "azurerm_private_dns_zone" "postgresql" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgresql" {
  name                  = "${var.env}-postgresql-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgresql.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
}

