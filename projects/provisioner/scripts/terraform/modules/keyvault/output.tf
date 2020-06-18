output "vaultUri" {
    value = "${azurerm_key_vault.vault.vault_uri}"
}

output "id" {
    value = "${azurerm_key_vault.vault.id}"
}

output "fullKeyPermissions" {
  description = "List of all the Key permissions to help key vault client setup user easier"
  value = [
    "backup",
    "create",
    "decrypt",
    "delete",
    "encrypt",
    "get",
    "import",
    "list",
    "purge",
    "recover",
    "restore",
    "sign",
    "unwrapKey",
    "update",
    "verify",
    "wrapKey",
  ]
}

output "fullSecretPermissions" {
  description = "List of all the Secret permissions to help key vault client setup user easier"
  value = [
    "get",
    "list",
    "set",
    "delete",
    "recover",
    "backup",
    "restore",
  ]
}

output "fullCertPermissions" {
  description = "List of all the Cert permissions to help key vault client setup user easier"
  value = [
    "backup",
    "create",
    "delete",
    "deleteissuers",
    "get",
    "getissuers",
    "import",
    "list",
    "listissuers",
    "managecontacts",
    "manageissuers",
    "purge",
    "recover",
    "restore",
    "setissuers",
    "update",
  ]
}
