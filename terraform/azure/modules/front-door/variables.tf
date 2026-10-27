variable "name_prefix" {
  description = "Prefix used for Azure Front Door resource names"
  type        = string
}

variable "endpoint_name" {
  description = "Globally unique Azure Front Door endpoint name"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group containing Azure Front Door resources"
  type        = string
}

variable "location" {
  description = "Azure region containing the Application Gateway Private Link origin"
  type        = string
}

variable "application_gateway_id" {
  description = "Resource ID of the Application Gateway origin"
  type        = string
}

variable "application_gateway_private_ip" {
  description = "Private frontend IP address of the Application Gateway origin"
  type        = string
}

variable "application_gateway_frontend_ip_configuration_name" {
  description = "Application Gateway frontend IP configuration exposed through Private Link"
  type        = string
}

variable "tags" {
  description = "Tags applied to Azure Front Door resources that support tags"
  type        = map(string)
  default     = {}
}
