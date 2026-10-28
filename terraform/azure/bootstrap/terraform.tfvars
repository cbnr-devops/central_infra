location             = "australiaeast"
resource_group_name  = "central-infra-tf-state-rg"
storage_account_name = "sksinfratfstate"

# Override only when an environment needs an additional state container.
state_containers = [
  "cicd-tfstate",
  "dev-tfstate",
  "shared-tfstate",
  "staging-tfstate",
]
