terraform {
  required_version = "=0.12.19"
  backend "azurerm" {
    storage_account_name = "nucleusterraformdev"
    container_name       = "tfstate"
    key                  = "shared-services-qe"
  }
}

provider "azurerm" {
  version = "=1.44.0"
  subscription_id = "510dd537-5356-41c7-b31d-65d9a93016e1"
}

provider "kubernetes" {
  version = "=1.10.0"
}