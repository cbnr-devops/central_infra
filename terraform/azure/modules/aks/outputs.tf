output "cluster_name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "cluster_id" {
  value = azurerm_kubernetes_cluster.this.id
}

output "kubelet_identity_object_id" {
  description = "Object ID of the AKS kubelet managed identity"
  value       = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL used for AKS workload identity federation"
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "kube_config_host" {
  description = "AKS API server endpoint used by Kubernetes-compatible providers"
  value       = azurerm_kubernetes_cluster.this.kube_config[0].host
  sensitive   = true
}

output "kube_config_cluster_ca_certificate" {
  description = "Base64-encoded AKS cluster CA certificate"
  value       = azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate
  sensitive   = true
}

output "agic_identity_object_id" {
  description = "Object ID of the managed identity used by the AGIC add-on"
  value       = try(azurerm_kubernetes_cluster.this.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id, null)
}
