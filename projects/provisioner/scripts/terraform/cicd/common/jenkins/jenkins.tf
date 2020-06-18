# Create public IPs
resource "azurerm_public_ip" "jenkinspublicip" {
    name                = "jenkins-public-ip"
    location            = "${var.rsgLocation}"
    resource_group_name = "${var.rsgName}"
    allocation_method   = "Static"

    tags = {
        environment = "${var.envTag}"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "jenkinsnsg" {
    name                = "jenkins-security"
    location            = "${var.rsgLocation}"
    resource_group_name = "${var.rsgName}"

    # TODO - remove later when ansible runs via jump box
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "HTTPS"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "Slave_Port"
        priority                   = 1010
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "TCP"
        source_port_range          = "*"
        destination_port_range     = "50000"
        source_address_prefix      = "*"
        destination_address_prefix = "${var.classCPlus}.0/21"
    }

    tags = {
        environment = "${var.envTag}"
    }
}

# Create network interface
resource "azurerm_network_interface" "jenkinsnic" {
    name                      = "jenkins-nic"
    location                  = "${var.rsgLocation}"
    resource_group_name       = "${var.rsgName}"
    network_security_group_id = "${azurerm_network_security_group.jenkinsnsg.id}"

    ip_configuration {
        name                          = "jenkins-nic-config"
        subnet_id                     = "${var.rsgSubnetId}"
        private_ip_address_allocation = "dynamic"
        public_ip_address_id          = "${azurerm_public_ip.jenkinspublicip.id}"
    }

    provisioner "local-exec" {
      command= "./add-dns-a.sh ${var.dnsName} ${azurerm_public_ip.jenkinspublicip.ip_address}"
    }

    provisioner "local-exec" {
      command= "./remove-dns-a.sh ${var.dnsName} ${azurerm_public_ip.jenkinspublicip.ip_address}"
      when = destroy
    }

    tags = {
        environment = "${var.envTag}"
    }
}

# resource "azurerm_dns_a_record" "jenkinsdnsname" {
#   name                = "test"
#   zone_name           = "${azurerm_dns_zone.test.name}"
#   resource_group_name = "${azurerm_resource_group.test.name}"
#   ttl                 = 300
#   records             = ["10.0.180.17"]
# }

resource "azurerm_managed_disk" "jenkinsdatadisk" {
  name = "jenkinsDataDisk"
  location = "${var.rsgLocation}"
  resource_group_name = "${var.rsgName}"
  storage_account_type = "Standard_LRS"
  create_option = "Empty"
  disk_size_gb = "256"

  tags = {
    environment = "${var.envTag}"
  }
}

data "azurerm_client_config" "current" {}

# https://github.com/terraform-providers/terraform-provider-azurerm/issues/1569
resource "azurerm_key_vault_access_policy" "jenkinsvaultaccess" {
  key_vault_id = "${var.buildVaultId}"
  tenant_id = "${data.azurerm_client_config.current.tenant_id}"
  object_id = "${var.jenkinsSvcObjId}"
  key_permissions = [
    "get",
  ]

  secret_permissions = [
    "get"
  ]

  storage_permissions = [
    "get",
  ]

  certificate_permissions = [
    "get",
  ]
}

resource "azurerm_container_registry" "jenkinsdevregistry" {
  name = "jenkinsDevRegistry"
  location =  "${var.rsgLocation}"
  resource_group_name = "${var.rsgName}"
  admin_enabled = false
  sku = "Standard"
  tags = {
    environment = "${var.envTag}"
  }
}

data "azurerm_subscription" "current" {}

locals {
  jenkins_ansible_vars = {
    BoxIp = "${azurerm_public_ip.jenkinspublicip.ip_address}"
    ServerName = "${var.serverName}"
    SubscriptionId = "${data.azurerm_subscription.current.subscription_id}"
    DevSubscriptionId = "${var.devSubscriptionId}"
    ResourceGroupName = "${var.rsgName}"
    ResourceGroupLocation = "${var.primaryLocation}"
    GithubProdPwd = "${var.githubProdPwd}"
    GithubProdUser = "${var.githubProdUser}"
    NucleusBuilderPwd = "${var.nucleusBuilderPwd}"
    JiraPwd = "${var.jiraPwd}"
    JiraUsername = "${var.jiraUsername}"
    JenkinsAadClientId = "${var.jenkinsAadClientId}"
    JenkinsAadAPIKey = "${var.jenkinsAadAPIKey}"
    JenkinsAadTenantId = "${var.jenkinsAadTenantId}"
    JenkinsSvcTenantId = "${var.jenkinsSvcTenantId}"
    JenkinsSvcClientId = "${var.jenkinsSvcClientId}"
    JenkinsSvcAPIKey = "${var.jenkinsSvcAPIKey}"
    JenkinsDevSvcTenantId = "${var.jenkinsDevSvcTenantId}"
    JenkinsDevSvcClientId = "${var.jenkinsDevSvcClientId}"
    JenkinsDevSvcAPIKey = "${var.jenkinsDevSvcAPIKey}"
    GitHash = "${var.gitHash}"
    DevRegistryUrl = "${azurerm_container_registry.jenkinsdevregistry.login_server}"
  }
}
# Create virtual machine
resource "azurerm_virtual_machine" "jenkinsvm" {
    name                  = "jenkins"
    location              = "${var.rsgLocation}"
    resource_group_name   = "${var.rsgName}"
    network_interface_ids = ["${azurerm_network_interface.jenkinsnic.id}"]
    vm_size               = "Standard_B2ms"

    storage_os_disk {
        name              = "jenkinsOsDisk"
        managed_disk_type = "Premium_LRS"
        create_option = "FromImage"
        os_type       = "linux"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

    delete_os_disk_on_termination = true

    storage_data_disk {
      name              = "${azurerm_managed_disk.jenkinsdatadisk.name}"
      managed_disk_id   = "${azurerm_managed_disk.jenkinsdatadisk.id}"
      create_option     = "Attach"
      disk_size_gb      = "${azurerm_managed_disk.jenkinsdatadisk.disk_size_gb}"
      lun               = 0
    }

    os_profile {
        computer_name  = "jenkins"
        admin_username = "${var.login}"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/${var.login}/.ssh/authorized_keys"
            key_data = "${var.sshPublicKey}"
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${var.rsgDiagSAEndpoint}"
    }

    tags = {
        environment = "${var.envTag}"
    }

    provisioner "local-exec" {
      working_dir = "${path.module}"
      command= "ansible-galaxy install --force --role-file=jenkins_requirements.yml"
    }

    provisioner "local-exec" {
      working_dir = "${path.module}"
      command= "../../run_ansible.sh jenkins_playbook.yml ${azurerm_public_ip.jenkinspublicip.ip_address} ${var.login} ${var.sshPrivateKeyFile} '${jsonencode(local.jenkins_ansible_vars)}'"
    }
}
