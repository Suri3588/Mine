# Create a Basic Key Vault

This creates a basic key vault along with some diagnostics. Once setup, you can add access policies
separately using the output ID and use the output URI for other clients.

Note that this looks up the tenant ID from the current client config - this vault will be in
that tenant.

## Example

``` HCL
# This is using info from the regrp module which sets up a diag storage account
module "keyvault" {
  source = "../modules/keyvault"
  envTag              = "${var.envTag}"
  vaultName           = "${var.vaultName}"
  rsgLocation         = "${module.resgroup.location}"
  rsgDiagSAId         = "${module.resgroup.diagSAId}"
  rsgName             = "${var.resourceName}"
}
```

To add access policies:

``` HCL
# Need this provider to lookup user and group info
provider azuread {
}

data "azuread_user" "vaultadmin" {
  user_principal_name = "dave@blah.blah"
}

resource "azurerm_key_vault_access_policy" "vaultadmin" {
  key_vault_id = "${module.keyvault.id}"
  tenant_id = "${data.azurerm_client_config.current.tenant_id}"
  object_id = "${data.azuread_user.vaultadmin.id}"

  key_permissions = module.keyvault.fullKeyPermissions

  secret_permissions = module.keyvault.fullSecretPermissions

  certificate_permissions = module.keyvault.fullCertPermissions
}
```
