resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.cluster_name
  kubernetes_version  = "1.29"

  default_node_pool {
    name           = "default"
    node_count     = 2
    min_count      = 2
    max_count      = 3
    vm_size        = var.vm_size
    vnet_subnet_id = var.subnet_id

    enable_auto_scaling = true
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

  tags = {
    Environment = var.env
    Project     = "central-infra"
  }
}
