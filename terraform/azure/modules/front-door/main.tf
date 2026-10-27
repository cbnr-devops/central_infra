locals {
  profile_name         = "${var.name_prefix}-afd"
  origin_group_name    = "${var.name_prefix}-appgw-origin-group"
  origin_name          = "${var.name_prefix}-appgw-origin"
  route_name           = "${var.name_prefix}-route"
  firewall_policy_name = replace("${var.name_prefix}-afd-waf", "-", "")
}

resource "azurerm_cdn_frontdoor_profile" "this" {
  name                = local.profile_name
  resource_group_name = var.resource_group_name
  sku_name            = "Premium_AzureFrontDoor"

  tags = var.tags
}

resource "azurerm_cdn_frontdoor_endpoint" "this" {
  name                     = var.endpoint_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  enabled                  = true

  tags = var.tags
}

resource "azurerm_cdn_frontdoor_origin_group" "this" {
  name                     = local.origin_group_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  session_affinity_enabled = false

  load_balancing {
    additional_latency_in_milliseconds = 0
    sample_size                        = 4
    successful_samples_required        = 3
  }

  health_probe {
    interval_in_seconds = 30
    path                = "/solar/live"
    protocol            = "Http"
    request_type        = "GET"
  }
}

resource "azurerm_cdn_frontdoor_origin" "application_gateway" {
  name                           = local.origin_name
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.this.id
  enabled                        = true
  certificate_name_check_enabled = true
  host_name                      = var.application_gateway_private_ip
  origin_host_header             = var.application_gateway_private_ip
  http_port                      = 80
  https_port                     = 443
  priority                       = 1
  weight                         = 1000

  private_link {
    location               = var.location
    private_link_target_id = var.application_gateway_id
    request_message        = "Azure Front Door access to the private Application Gateway origin"
    target_type            = "Gateway"
  }
}

resource "azurerm_cdn_frontdoor_route" "this" {
  name                          = local.route_name
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.this.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.this.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.application_gateway.id]
  enabled                       = true

  forwarding_protocol    = "HttpOnly"
  https_redirect_enabled = true
  link_to_default_domain = true
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]
}

resource "azurerm_cdn_frontdoor_firewall_policy" "this" {
  name                = local.firewall_policy_name
  resource_group_name = var.resource_group_name
  sku_name            = azurerm_cdn_frontdoor_profile.this.sku_name
  enabled             = true
  mode                = "Prevention"

  managed_rule {
    type    = "Microsoft_DefaultRuleSet"
    version = "2.1"
    action  = "Block"
  }

  managed_rule {
    type    = "Microsoft_BotManagerRuleSet"
    version = "1.1"
    action  = "Block"
  }

  tags = var.tags
}

resource "azurerm_cdn_frontdoor_security_policy" "this" {
  name                     = "${var.name_prefix}-security-policy"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.this.id

      association {
        patterns_to_match = ["/*"]

        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.this.id
        }
      }
    }
  }
}
