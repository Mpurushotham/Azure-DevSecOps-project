output "resource_group" {
  value = azurerm_resource_group.rg.name
}
output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}
output "aks_name" {
  value = azurerm_kubernetes_cluster.aks.name
}
output "log_analytics_id" {
  value = azurerm_log_analytics_workspace.law.id
}
