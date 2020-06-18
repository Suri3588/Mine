terraform {
  backend "azurerm" {
    storage_account_name = "nucleusterraformprod"
    container_name       = "tfstate"
    key                  = "cicd"
  }
}

module "subscript" {
  source = "../../modules/subscriptions"
}

provider "azurerm" {
  subscription_id = "${module.subscript.id}"
}

module "resgroup" {
  source = "../../modules/resgroup"
  classCPlus           = "${var.classCPlus}"
  envTag               = "${var.envTag}"
  resourceName         = "${var.resourceName}"
}

module "keyvault" {
  source = "../../modules/keyvault"
  envTag              = "${var.envTag}"
  vaultName           = "${var.vaultName}"
  rsgLocation         = "${module.resgroup.location}"
  rsgDiagSAId         = "${module.resgroup.diagSAId}"
  rsgName             = "${var.resourceName}"
}

data "azurerm_client_config" "current" {}

data "azuread_group" "vaultadmingroup" {
  name = "DevOps"
}

resource "azurerm_key_vault_access_policy" "vaultadmingroup" {
  key_vault_id = "${module.keyvault.id}"
  tenant_id = "${data.azurerm_client_config.current.tenant_id}"
  object_id = "${data.azuread_group.vaultadmingroup.id}"

  key_permissions = module.keyvault.fullKeyPermissions
  secret_permissions = module.keyvault.fullSecretPermissions
  certificate_permissions = module.keyvault.fullCertPermissions
}

# For now, let dave have access
data "azuread_user" "vaultadmin" {
  user_principal_name = "dreich@NucleusHealth.onmicrosoft.com"
}

resource "azurerm_key_vault_access_policy" "vaultadmin" {
  key_vault_id = "${module.keyvault.id}"
  tenant_id = "${data.azurerm_client_config.current.tenant_id}"
  object_id = "${data.azuread_user.vaultadmin.id}"

  key_permissions = module.keyvault.fullKeyPermissions
  secret_permissions = module.keyvault.fullSecretPermissions
  certificate_permissions = module.keyvault.fullCertPermissions
}

module "jenkins" {
  source = "../common/jenkins"

  rsgLocation         = "${module.resgroup.location}"
  rsgName             = "${module.resgroup.name}"
  rsgSubnetId         = "${module.resgroup.subnetId}"
  rsgDiagSAEndpoint   = "${module.resgroup.diagSAEndpoint}"
  primaryLocation     = "${module.resgroup.primaryLocation}"

  envTag = "${var.envTag}"
  gitHash = "${var.gitHash}"
  jiraUsername = "${var.jiraUsername}"
  jiraPwd = "${var.jiraPwd}"
  githubProdUser = "${var.githubProdUser}"
  githubProdPwd = "${var.githubProdPwd}"
  nucleusBuilderPwd = "${var.nucleusBuilderPwd}"

  vaultAdminUser = "${var.vaultAdminUser}"
  buildVaultId = "${module.keyvault.id}"
  jenkinsAadTenantId = "${var.jenkinsAadTenantId}"
  jenkinsAadAPIKey = "${var.jenkinsAadAPIKey}"
  jenkinsAadClientId = "${var.jenkinsAadClientId}"
  jenkinsSvcAPIKey = "${var.jenkinsSvcAPIKey}"
  jenkinsSvcClientId = "${var.jenkinsSvcClientId}"
  jenkinsSvcObjId = "${var.jenkinsSvcObjId}"
  jenkinsSvcTenantId = "${var.jenkinsSvcTenantId}" # lookup from current config
  # rename dev to other
  devSubscriptionId = "${var.devSubscriptionId}"
  jenkinsDevSvcAPIKey = "${var.jenkinsDevSvcAPIKey}"
  jenkinsDevSvcClientId = "${var.jenkinsDevSvcClientId}"
  jenkinsDevSvcTenantId = "${var.jenkinsDevSvcTenantId}"
  sshPublicKey = "${var.sshPublicKey}"
  sshPrivateKeyFile = "../../${module.subscript.environment}/secretfiles/${var.sshPrivateKeyFile}"
  dnsName = "${module.subscript.environment}-cicd"
}

# module "jumpbox" {
#   source = "../modules/jumpbox"

#   rsgSubnetId          = "${module.resgroup.subnetId}"
#   rsgDiagSAEndpoint    = "${module.resgroup.diagSAEndpoint}"
#   envTag               = "${var.envTag}"
#   login                = "${var.login}"
#   nvmVersion           = "0.33.8"
#   nodeVersion          = "10.13.0"
#   rsgLocation          = "${module.resgroup.location}"
#   rsgName              = "${module.resgroup.name}"
#   sshPublicKey         = "${var.sshPublicKey}"
#   sshPrivateKeyFile    = "../../cicd/${module.subscript.environment}/secretfiles/${var.sshPrivateKeyFile}"
# }
