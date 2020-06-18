output "storageAccountEndpoints" {
    value = "${join(",", azurerm_storage_account.accounts.*.primary_blob_endpoint)}"
}
