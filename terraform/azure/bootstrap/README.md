# Azure Terraform bootstrap

This Terraform root creates the remote-state infrastructure used by the other
Azure environment roots. It intentionally uses local state because the remote
backend does not exist before the first apply.

The AzureRM provider idempotently ensures that the resource providers listed in
`resource_providers` are registered. Existing registrations are left in place.

## Prerequisites

- Azure CLI authenticated to the target subscription.
- Permission to register resource providers.
- Permission to create the resource group and storage resources.
- A globally unique value for `storage_account_name`.

## Run

```bash
cd terraform/azure/bootstrap
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -out bootstrap.tfplan
terraform apply bootstrap.tfplan
```

Keep the generated local `terraform.tfstate` secure. It is ignored by Git and
is required to update or destroy the bootstrap resources declaratively.

After this apply, configure the `shared`, `cicd`, `dev`, and `staging` roots to
use the created storage account and their corresponding containers.
