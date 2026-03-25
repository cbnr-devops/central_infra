terraform {
  backend "azurerm" {
    resource_group_name  = "central-infra-tf-state-rg"
    storage_account_name = "centralinfratfstate"
    container_name       = "tfstate"
    key                  = "dev/terraform.tfstate"
  }
}
