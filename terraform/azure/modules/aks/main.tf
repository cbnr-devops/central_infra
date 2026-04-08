resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.cluster_name
  kubernetes_version  = "1.34"

  default_node_pool {
    name           = "default"
    node_count     = 1
    min_count      = 1
    max_count      = 2
    vm_size        = var.vm_size
    vnet_subnet_id = var.subnet_id
    auto_scaling_enabled = true
    max_pods            = var.max_pods
    temporary_name_for_rotation = "tmpdefault"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    service_cidr   = "10.200.0.0/16"
    dns_service_ip = "10.200.0.10"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  oms_agent {
    log_analytics_workspace_id      = var.log_analytics_workspace_id
    msi_auth_for_monitoring_enabled = true
  }
  
  monitor_metrics {
    annotations_allowed = null
    labels_allowed      = null
  }
  
  tags = {
    Environment = var.env
    Project     = "central-infra"
  }
}
