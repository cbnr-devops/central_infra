resource "azurerm_monitor_workspace" "this" {
  name                = "${var.env}-monitor-workspace"
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_dashboard_grafana" "this" {
  name                              = "${var.env}-grafana"
  resource_group_name               = var.resource_group_name
  location                          = var.location
  sku                               = "Standard"
  grafana_major_version             = "11"
  public_network_access_enabled     = true

  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.this.id
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "grafana_monitor_reader" {
  scope                = azurerm_monitor_workspace.this.id
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.this.identity[0].principal_id
}

resource "azurerm_monitor_data_collection_rule" "prometheus" {
  name                = "${var.env}-prometheus-dcr"
  resource_group_name = var.resource_group_name
  location            = var.location

  destinations {
    monitor_account {
      monitor_account_id = azurerm_monitor_workspace.this.id
      name               = "prometheus-destination"
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["prometheus-destination"]
  }

  data_sources {
    prometheus_forwarder {
      streams = ["Microsoft-PrometheusMetrics"]
      name    = "prometheus-forwarder"
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "prometheus" {
  name                    = "${var.env}-prometheus-dcra"
  target_resource_id      = var.aks_cluster_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.prometheus.id
}