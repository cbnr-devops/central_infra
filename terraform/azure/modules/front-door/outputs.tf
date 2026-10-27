output "profile_id" {
  description = "Resource ID of the Azure Front Door profile"
  value       = azurerm_cdn_frontdoor_profile.this.id
}

output "endpoint_hostname" {
  description = "Default Azure Front Door endpoint hostname"
  value       = azurerm_cdn_frontdoor_endpoint.this.host_name
}

output "endpoint_url" {
  description = "Default HTTPS URL of the Azure Front Door endpoint"
  value       = "https://${azurerm_cdn_frontdoor_endpoint.this.host_name}"
}

output "firewall_policy_id" {
  description = "Resource ID of the Azure Front Door WAF policy"
  value       = azurerm_cdn_frontdoor_firewall_policy.this.id
}
