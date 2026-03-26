resource "azurerm_resource_group" "this" {
  name     = "central-${var.env}-rg"
  location = var.azure_region

  tags = {
    Environment = var.env
    Project     = "central-infra"
  }
}
