terraform {
  backend "azurerm" {
    storage_account_name = "blahrandhhahsstate"
    container_name       = "tfstate"
    key                  = "whatterraformtfstate"
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
  classCPlus           = "10.40.0"
  envTag               = "${var.envTag}"
  resourceName         = "eng_testing_stuff_dr"
}

module "jumpbox" {
  source = "../../modules/jumpbox"

  rsgSubnetId          = "${module.resgroup.subnetId}"
  rsgDiagSAEndpoint    = "${module.resgroup.diagSAEndpoint}"
  classCPlusOffset     = "10.40.6"
  envTag               = "${var.envTag}"
  nvmVersion           = "0.33.8"
  nodeVersion          = "10.13.0"
  rsgLocation          = "${module.resgroup.location}"
  rsgName              = "${module.resgroup.name}"
  sshPublicKey         = "${var.sshPublicKey}"
  sshPrivateKeyFile    = "../../testing/${module.subscript.environment}/secretfiles/${var.sshPrivateKeyFile}"
}