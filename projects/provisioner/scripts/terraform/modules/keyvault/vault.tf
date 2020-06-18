# #######################################################
#  Create a key vault

data "azurerm_client_config" "current" {}

# Note, the spObjId is the object ID of the service principal
# When you setup an App Registration, a second object is created
# that shares the same name and application (client) ID. 
# Do Not Use that object ID here. Instead, go to the "Enterprise Applications"
# and find the principal you want. Use the Object ID from there.
# Or, using az cli
# az ad sp show --id <Application (client) ID>
resource "azurerm_key_vault" "vault" {
  name                = "${var.vaultName}"
  location            = "${var.rsgLocation}"
  resource_group_name = "${var.rsgName}"
  tenant_id           = "${data.azurerm_client_config.current.tenant_id}"
  sku_name            = "standard"
  enabled_for_deployment = true

  tags = {
      environment = "${var.envTag}"
  }
}
resource "azurerm_monitor_diagnostic_setting" "vaultdiag" {
  name               = "vaultdiag"
  target_resource_id = "${azurerm_key_vault.vault.id}"
  storage_account_id = "${var.rsgDiagSAId}"

  log {
    category = "AuditEvent"

    retention_policy {
      enabled = false
    }
  }

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = false
    }
  }
}
