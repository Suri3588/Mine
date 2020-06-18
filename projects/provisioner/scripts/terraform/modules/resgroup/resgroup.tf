# #######################################################
#  Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "resgrp_rsg" {
    name     = var.resourceName
    location = var.primaryLocation

    tags = {
        environment = var.envTag
    }
}

# #######################################################
# Create the virtual network
resource "azurerm_virtual_network" "resgrp_vnet" {
    name                = "${var.resourceName}-vnet"
    address_space       = ["${var.classCPlus}.0/21"]
    location            = azurerm_resource_group.resgrp_rsg.location
    resource_group_name = azurerm_resource_group.resgrp_rsg.name

    tags = {
        environment = var.envTag
    }
}

# Create subnet
resource "azurerm_subnet" "resgrp_subnet" {
    name                 = "${var.resourceName}-subnet"
    address_prefix       = "${var.classCPlus}.0/21"
    resource_group_name  = azurerm_resource_group.resgrp_rsg.name
    virtual_network_name = azurerm_virtual_network.resgrp_vnet.name
}

