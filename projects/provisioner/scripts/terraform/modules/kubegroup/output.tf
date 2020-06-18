output "cluster_name" {
  value = azurerm_kubernetes_cluster.kubgrp_aks.node_resource_group
}

output "dns_service_ip" {
  value = azurerm_kubernetes_cluster.kubgrp_aks.network_profile.0.dns_service_ip
}

output "docker_bridge_cidr" {
  value = azurerm_kubernetes_cluster.kubgrp_aks.network_profile.0.docker_bridge_cidr
}

output "network_plugin" {
  value = azurerm_kubernetes_cluster.kubgrp_aks.network_profile.0.network_plugin
}

output "pod_cidr" {
  value = azurerm_kubernetes_cluster.kubgrp_aks.network_profile.0.pod_cidr
}

output "service_cidr" {
  value = azurerm_kubernetes_cluster.kubgrp_aks.network_profile.0.service_cidr
}
