output "diagSAEndpoint" {
    value = azurerm_storage_account.diag.primary_blob_endpoint
}

output "diagSAId" {
    value = azurerm_storage_account.diag.id
}

output "location" {
    value = azurerm_resource_group.resgrp_rsg.location
}

output "Id" {
    value = azurerm_resource_group.resgrp_rsg.id
}

output "primaryLocation" {
    value = var.primaryLocation
}

output "name" {
    value = azurerm_resource_group.resgrp_rsg.name
}

output "subnetId" {
    value = azurerm_subnet.resgrp_subnet.id
}

output "vNetId" {
    value = azurerm_virtual_network.resgrp_vnet.id
}

output "vNetName" {
    value = azurerm_virtual_network.resgrp_vnet.name
}
