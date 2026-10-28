terraform {
  backend "azurerm" {
    resource_group_name  = "central-infra-tf-state-rg"
    storage_account_name = "sksinfratfstate"
    container_name       = "staging-tfstate"
    key                  = "staging/terraform.tfstate"
  }
}
