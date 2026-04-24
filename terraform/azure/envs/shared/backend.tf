terraform {
  backend "azurerm" {
    resource_group_name  = "central-shared-rg"
    storage_account_name = "sksinfratfstate"
    container_name       = "shared-tfstate"
    key                  = "shared/terraform.tfstate"
  }
}
