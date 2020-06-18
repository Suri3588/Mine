output "depended_on" {
  value = null_resource.dependency_setter.id
}

output "publicIpRsgId" {
  value = azurerm_resource_group.aks-public-ip.id
}
