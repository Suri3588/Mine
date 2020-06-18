# Generate random text for a unique storage account name
resource "random_id" "acct_id" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.resgrp_rsg.name
    }

    byte_length = 8
}

resource "azurerm_storage_account" "diag" {
  name                     = "${random_id.acct_id.hex}diag"
  resource_group_name      = azurerm_resource_group.resgrp_rsg.name
  location                 = azurerm_resource_group.resgrp_rsg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}