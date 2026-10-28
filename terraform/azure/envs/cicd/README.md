# CI/CD foundation

This Terraform root creates the networking and Azure control-plane resources
for the Azure DevOps Managed DevOps Pool.

The first phase creates:

- A dedicated CI/CD VNet.
- A subnet delegated exclusively to `Microsoft.DevOpsInfrastructure/pools`.
- A separate subnet reserved for private endpoints.
- A NAT Gateway with a stable public egress address.
- A Dev Center and Dev Center project.
- Role assignments for the `DevOpsInfrastructure` service principal, including
  gallery-wide image-reader access that remains stable across image definitions.
- A stateless Managed DevOps Pool using a version-qualified Azure Compute
  Gallery image created outside Terraform.

The ACR private endpoint is managed by the `shared` Terraform root after the
shared ACR exists. It is attached to the private-endpoint subnet created here,
and its private DNS zone is linked to this CI/CD VNet.

## Prerequisites

- The gallery image version is replicated, generalized, and supported by
  Managed DevOps Pools.
- The applying identity can create role assignments on the VNet and gallery.
- The applying user is a member of the target Azure DevOps organization and
project and has project-level Agent Pool Creator or Administrator permission.
- The Managed DevOps Pools VM-family quota is available in the selected region.
- The manually created CI/CD resource group has been imported at
  `azurerm_resource_group.cicd`.

## Run

```bash
cd terraform/azure/envs/cicd
cp terraform.tfvars.example terraform.tfvars
# Replace the Azure DevOps, gallery, and gallery image ID placeholders.
terraform init
terraform plan -out cicd.tfplan
terraform apply cicd.tfplan
```
