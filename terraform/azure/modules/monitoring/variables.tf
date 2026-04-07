variable "env" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "aks_cluster_id" {
  description = "AKS cluster resource ID to associate DCR with"
  type        = string
}
