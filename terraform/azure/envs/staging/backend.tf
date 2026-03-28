terraform {
  backend "azurerm" {
    resource_group_name  = "central-infra-tf-state-rg"
    storage_account_name = "solarinfratfstate"
    container_name       = "staging-tfstate"
    key                  = "staging/terraform.tfstate"
  }
}
