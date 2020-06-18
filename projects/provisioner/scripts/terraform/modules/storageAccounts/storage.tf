locals {
  count = "${length(split(",", var.tails))}"
}

# Generate random text for a unique storage account name
resource "random_id" "storage_acct_id" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${var.rsgName}"
    }

    byte_length = 8
}

resource "azurerm_storage_account" "accounts" {
  count                    = "${local.count}"
  name                     = "${random_id.storage_acct_id.hex}${element(split(",", var.tails), count.index)}"
  resource_group_name      = "${var.rsgName}"
  location                 = "${var.rsgLocation}"
  account_tier             = "Standard"
  account_replication_type = "${element(split(",", var.types), count.index)}"
}