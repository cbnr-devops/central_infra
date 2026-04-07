output "grafana_endpoint" {
  value = azurerm_dashboard_grafana.this.endpoint
}

output "monitor_workspace_id" {
  value = azurerm_monitor_workspace.this.id
}
