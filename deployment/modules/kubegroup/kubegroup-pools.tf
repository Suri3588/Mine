resource "azurerm_kubernetes_cluster_node_pool" "kubgrp_aks_node_pool" {
  # TODO: This is how we would hand control of the node pool sizes to kubernetes auto node count management
  # lifecycle {
  #  ignore_changes = [ node_count ]
  #}
  
  for_each = var.additional_node_pools
    kubernetes_cluster_id = azurerm_kubernetes_cluster.kubgrp_aks.id
    name                  = each.value.node_os == "Windows" ? substr(each.key, 0, 6) : substr(each.key, 0, 12)
    node_count            = each.value.node_count
    vm_size               = each.value.vm_size
    availability_zones    = each.value.zones
    max_pods              = each.value.max_pods
    os_disk_size_gb       = each.value.os_disk_size_gb
    os_type               = each.value.node_os
    vnet_subnet_id        = var.rsgSubnetId
    node_taints           = each.value.taints
    enable_auto_scaling   = each.value.cluster_auto_scaling
    min_count             = each.value.cluster_auto_scaling_min_count
    max_count             = each.value.cluster_auto_scaling_max_count
}