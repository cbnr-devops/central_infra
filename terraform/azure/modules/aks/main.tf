resource "azurerm_kubernetes_cluster" "this" {
  name                   = var.cluster_name
  location               = var.location
  resource_group_name    = var.resource_group_name
  dns_prefix             = var.cluster_name
  kubernetes_version     = "1.34"
  local_account_disabled = true

  default_node_pool {
    name                        = "default"
    node_count                  = 1
    min_count                   = 1
    max_count                   = 2
    vm_size                     = var.vm_size
    vnet_subnet_id              = var.subnet_id
    auto_scaling_enabled        = true
    max_pods                    = var.max_pods
    temporary_name_for_rotation = "tmpdefault"

    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type = "SystemAssigned"
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }

  api_server_access_profile {
    authorized_ip_ranges = var.api_server_authorized_ip_ranges
  }

  network_profile {
    network_plugin = "azure"
    outbound_type  = "userAssignedNATGateway"
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

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count,
    ]
  }

  tags = {
    Environment = var.env
    Project     = "central-infra"
  }
}

data "azurerm_client_config" "current" {}
