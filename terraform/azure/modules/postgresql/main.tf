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