output "server_name" {
  description = "PostgreSQL server name"
  value       = azurerm_postgresql_flexible_server.this.name
}

output "server_fqdn" {
  description = "Fully qualified domain name of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

output "database_name" {
  description = "Name of the planets database"
  value       = azurerm_postgresql_flexible_server_database.planets.name
}

output "server_id" {
  description = "Resource ID of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.this.id
}
