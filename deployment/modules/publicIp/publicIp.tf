resource "null_resource" "dependency_setter" {
  depends_on = [ azurerm_public_ip.aks-public-ip ]
}

resource "azurerm_resource_group" "aks-public-ip" {
  name     = "${var.rsgName}-ip"
  location = var.rsgLocation
}

resource "azurerm_public_ip" "aks-public-ip" {
  depends_on          = [ azurerm_resource_group.aks-public-ip ]

  name                = "${var.dnsPrefix}-public-ip"
  sku                 = "Basic"
  allocation_method   = "Static"
  resource_group_name = "${var.rsgName}-ip"
  location            = var.rsgLocation
}

resource "null_resource" "dns_remover" {
   triggers = {
    path  = path.module
  }

  provisioner "local-exec" {
    working_dir = self.triggers.path
    command = "./delete-dns.sh"
    when = destroy
  }
}