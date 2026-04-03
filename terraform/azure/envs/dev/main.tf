module "resource_group" {
  source       = "../../modules/resource-group"
  env          = "dev"
  azure_region = var.azure_region
}

module "vnet" {
  source              = "../../modules/vnet"
  env                 = "dev"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  vnet_cidr           = var.vnet_cidr
}

module "aks" {
  source              = "../../modules/aks"
  env                 = "dev"
  cluster_name        = "dev-cluster"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  subnet_id           = module.vnet.private_subnet_id
  vm_size             = var.vm_size
  max_pods            = 100
}
