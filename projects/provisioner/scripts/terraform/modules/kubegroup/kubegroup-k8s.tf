resource "null_resource" "dependency_getter" {
  provisioner "local-exec" {
    command = "echo ${length(var.dependencies)}"
  }
}

resource "azurerm_kubernetes_cluster" "kubgrp_aks" {
  lifecycle {
    ignore_changes = [ service_principal, role_based_access_control, windows_profile ]
  }

  depends_on          = [ null_resource.dependency_getter ]

  name                = "${var.rsgName}-aks"
  dns_prefix          = "${var.dnsPrefix}-dns"
  node_resource_group = "${var.rsgName}-aks"
  location            = var.rsgLocation
  resource_group_name = var.rsgName
  kubernetes_version  = var.kubernetes_version

  linux_profile {
    admin_username = "aksAdmin"

    ssh_key {
      key_data = var.regaksPublicKey
    }
  }
  
  default_node_pool {
    name           = "default"
    node_count     = 2
    max_pods       = 30
    type           = "VirtualMachineScaleSets"
    vm_size        = "Standard_DS3_v2"
    vnet_subnet_id = var.rsgSubnetId
  }

  service_principal {
    client_id     = var.akcPrincipal
    client_secret = var.akcPrincipalPassword
  }

  network_profile {
    network_plugin = "azure"
  }

  role_based_access_control {
    enabled = true

    azure_active_directory {
      client_app_id     = var.aksAadClientId
      server_app_id     = var.aksAadServerId
      server_app_secret = var.aksAadServerSecret
      tenant_id         = var.aksAadTenantId
    }
  }

  provisioner "local-exec" {
    working_dir = path.module
    command = "./update-ingress-nginx.sh"
  }

  provisioner "local-exec" {
    working_dir = path.module
    command = "./update-shared-services.sh"
  }
}

resource "null_resource" "principal_role_assigner" {
   triggers = {
    akcPrincipal  = var.akcPrincipal
    vnetId        = var.vnetId
    publicIpRsgId = var.publicIpRsgId
  }

  provisioner "local-exec" {
    command = "az role assignment create --assignee ${self.triggers.akcPrincipal} --role 'Network Contributor' --scope ${self.triggers.vnetId}"
  }

  provisioner "local-exec" {
    command = "az role assignment create --assignee ${self.triggers.akcPrincipal} --role 'Contributor' --scope ${self.triggers.publicIpRsgId}"
  }

  provisioner "local-exec" {
    command = "az role assignment delete --assignee ${self.triggers.akcPrincipal} --role 'Network Contributor' --scope ${self.triggers.vnetId} --yes"
    when = destroy
  }

  provisioner "local-exec" {
    command = "az role assignment delete --assignee ${self.triggers.akcPrincipal} --role 'Contributor' --scope ${self.triggers.publicIpRsgId} --yes"
    when = destroy
  }
}
