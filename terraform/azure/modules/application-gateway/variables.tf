variable "name_prefix" {
  description = "Prefix used for Application Gateway resource names"
  type        = string
}

variable "location" {
  description = "Azure region in which to create Application Gateway"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group containing Application Gateway"
  type        = string
}

variable "subnet_id" {
  description = "Resource ID of the dedicated Application Gateway subnet"
  type        = string
}

variable "private_link_subnet_id" {
  description = "Resource ID of the dedicated subnet used by the Application Gateway Private Link configuration"
  type        = string
}

variable "private_ip_address" {
  description = "Static private frontend address for Application Gateway"
  type        = string
}

variable "tags" {
  description = "Tags applied to Application Gateway resources"
  type        = map(string)
  default     = {}
}
