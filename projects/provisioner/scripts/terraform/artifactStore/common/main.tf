resource "azurerm_resource_group" "resgrp" {
    name     = var.resourceName
    location = var.primaryLocation

    tags = {
        environment = var.envTag
    }
}

# Generate random text for a unique storage account name
resource "random_id" "acct_id" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.resgrp.name
    }

    byte_length = 8
}

resource "azurerm_storage_account" "diag" {
  name                     = "${random_id.acct_id.hex}diag"
  resource_group_name      = azurerm_resource_group.resgrp.name
  location                 = azurerm_resource_group.resgrp.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_account" "builds" {
  name                     = "${random_id.acct_id.hex}builds"
  resource_group_name      = azurerm_resource_group.resgrp.name
  location                 = azurerm_resource_group.resgrp.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_container_registry" "imageregistry" {
  name = "Nucleus${var.environment}Registry"
  location =  azurerm_resource_group.resgrp.location
  resource_group_name = azurerm_resource_group.resgrp.name
  admin_enabled = false
  sku = "Premium"
  tags = {
    environment = var.envTag
  }
}

resource "azurerm_role_assignment" "nucleusReader" {
  scope                = azurerm_container_registry.imageregistry.id
  role_definition_name = "Reader"
  principal_id         = var.registryReaderId
}

resource "azurerm_role_assignment" "nucleusAcrPull" {
  scope                = azurerm_container_registry.imageregistry.id
  role_definition_name = "AcrPull"
  principal_id         = var.registryReaderId
}

# Not sure we want a vault in the artifact store - there are no uses for it
# at the moment. But is we find one, uncomment this code.
# module "keyvault" {
#   source = "../../modules/keyvault"
#   envTag              = "${var.envTag}"
#   vaultName           = "NucleusKeyVault4${var.environment}"
#   rsgLocation         = "${azurerm_resource_group.resgrp.location}"
#   rsgDiagSAId         = "${azurerm_storage_account.diag.id}"
#   rsgName             = "${azurerm_resource_group.resgrp.name}"
# }