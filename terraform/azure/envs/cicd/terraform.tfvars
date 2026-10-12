location            = "australiaeast"
resource_group_name = "central-infra-cicd-rg"

azure_devops_organization_url = "https://dev.azure.com/skssolar"
azure_devops_project_name     = "sample-project"
managed_devops_pool_name      = "central-infra-mdp"

maximum_concurrency = 1
agent_vm_size       = "Standard_D2ads_v5"

gallery_image_definition_id = "/subscriptions/7543cdd5-e635-49b4-b18f-4663b5e9ea61/resourceGroups/central-infra-cicd-rg/providers/Microsoft.Compute/galleries/centralcicdgallery/images/central-devops-agent"
custom_image_alias          = "central-custom-linux"

vnet_cidr                    = "10.10.0.0/16"
agent_subnet_cidr            = "10.10.1.0/27"
private_endpoint_subnet_cidr = "10.10.2.0/27"
