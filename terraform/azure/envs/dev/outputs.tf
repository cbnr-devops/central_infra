output "resource_group_name" {
  value = module.resource_group.name
}

output "resource_group_location" {
  value = module.resource_group.location
}

output "grafana_endpoint" {
  value = module.monitoring.grafana_endpoint
}