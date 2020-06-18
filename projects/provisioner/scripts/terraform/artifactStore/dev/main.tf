terraform {
  backend "azurerm" {
    storage_account_name = "nucleusterraformdev"
    container_name       = "tfstate"
    key                  = "artifactStore"
  }
}

module "subscript" {
  source = "../../modules/subscriptions"
}

provider "azurerm" {
  subscription_id = module.subscript.id
}

module "common" {
  source = "../common"
  environment = module.subscript.environment
  registryReaderId = var.nucleusRegistryReaderId
}

# Not sure we want a vault in the artifact store - there are no uses for it
# at the moment. But is we find one, uncomment this code.
# data "azuread_group" "vaultadmin" {
#   name = "DevOps"
#   #object_id = "780df7fb-223e-4e91-9b03-34169cca0390"
# }

# data "azuread_user" "vaultadmin" {
#   user_principal_name = "dreich@NucleusHealthDEV.onmicrosoft.com"
# }

# data "azurerm_client_config" "current" {}

# resource "azurerm_key_vault_access_policy" "vaultadmin" {
#   key_vault_id = "${module.common.vaultid}"
#   tenant_id = "${data.azurerm_client_config.current.tenant_id}"
#   object_id = "${data.azuread_user.vaultadmin.id}"

#   key_permissions = module.common.fullKeyPermissions
#   secret_permissions = module.common.fullSecretPermissions
#   certificate_permissions = module.common.fullCertPermissions
# }