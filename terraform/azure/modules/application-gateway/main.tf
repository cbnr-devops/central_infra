locals {
  gateway_name               = "${var.name_prefix}-appgw"
  frontend_ip_configuration  = "private-frontend"
  private_link_configuration = "afd-private-link"
  frontend_port_name         = "http"
  backend_address_pool_name  = "bootstrap-backend-pool"
  backend_http_settings_name = "bootstrap-http-settings"
  http_listener_name         = "bootstrap-private-http-listener"
  request_routing_rule_name  = "bootstrap-routing-rule"
}

resource "azurerm_public_ip" "this" {
  name                = "${var.name_prefix}-appgw-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

resource "azurerm_application_gateway" "this" {
  name                = local.gateway_name
  location            = var.location
  resource_group_name = var.resource_group_name
  http2_enabled       = true

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "gateway-ip-configuration"
    subnet_id = var.subnet_id
  }

  frontend_ip_configuration {
    name                            = local.frontend_ip_configuration
    subnet_id                       = var.subnet_id
    private_ip_address              = var.private_ip_address
    private_ip_address_allocation   = "Static"
    private_link_configuration_name = local.private_link_configuration
  }

  frontend_ip_configuration {
    name                 = "unused-public-frontend"
    public_ip_address_id = azurerm_public_ip.this.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  private_link_configuration {
    name = local.private_link_configuration

    ip_configuration {
      name                          = "primary"
      subnet_id                     = var.private_link_subnet_id
      private_ip_address_allocation = "Dynamic"
      primary                       = true
    }
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.backend_http_settings_name
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
  }

  http_listener {
    name                           = local.http_listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    priority                   = 10000
    http_listener_name         = local.http_listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.backend_http_settings_name
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      backend_address_pool,
      backend_http_settings,
      frontend_port,
      http_listener,
      probe,
      redirect_configuration,
      request_routing_rule,
      rewrite_rule_set,
      url_path_map,
    ]
  }
}
