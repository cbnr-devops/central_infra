# CI/CD foundation

This Terraform root creates the networking and Azure control-plane resources
for the Azure DevOps Managed DevOps Pool.

The first phase creates:

- A dedicated CI/CD VNet.
- A subnet delegated exclusively to `Microsoft.DevOpsInfrastructure/pools`.
- A separate subnet reserved for private endpoints.
- A NAT Gateway with a stable public egress address.
- A Dev Center and Dev Center project.
- Role assignments for the `DevOpsInfrastructure` service principal.
- A stateless Managed DevOps Pool using an existing Azure Compute Gallery image
  definition created outside Terraform.

The ACR private endpoint is intentionally deferred until the shared ACR exists.

## Prerequisites

- The gallery image definition contains at least one replicated, generalized
  image version supported by Managed DevOps Pools.
- The applying identity can create role assignments on the VNet and image.
- The applying user is a member of the target Azure DevOps organization and
project and has project-level Agent Pool Creator or Administrator permission.
- The Managed DevOps Pools VM-family quota is available in the selected region.
- The manually created CI/CD resource group has been imported at
  `azurerm_resource_group.cicd`.

## Run

```bash
cd terraform/azure/envs/cicd
cp terraform.tfvars.example terraform.tfvars
# Replace the Azure DevOps and gallery image ID placeholders.
terraform init
terraform plan -out cicd.tfplan
terraform apply cicd.tfplan
```
