# Create Network Security Group and rule
resource "azurerm_network_security_group" "passthru_nsg" {
    name                = "passthru-security"
    location            = var.rsgLocation
    resource_group_name = var.rsgName

    security_rule {
        name                       = "HTTP"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "${var.classCPlus}.0/21"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "HTTP-shared"
        priority                   = 1012
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "10.1.0.0/21"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "HTTPS"
        priority                   = 1102
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "${var.classCPlus}.0/21"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "HTTPS-shared"
        priority                   = 1112
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "10.1.0.0/21"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "ssh"
        priority                   = 2002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "${var.classCPlusOffset}.105/32"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "prometheus"
        priority                   = 2010
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "9100"
        source_address_prefix      = "${var.passthruIp}/32"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "fluentd"
        priority                   = 2020
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "24224"
        source_address_prefix      = "10.0.0.0/8"
        destination_address_prefix = "${var.fluentdDest}/32"
    }

    security_rule {
        name                       = "Deny"
        priority                   = 4001
        direction                  = "Inbound"
        access                     = "Deny"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = var.envTag
    }
}

# Create network interface
resource "azurerm_network_interface" "passthru_nic" {
    name                      = "passthru-nic1"
    location                  = var.rsgLocation
    resource_group_name       = var.rsgName
    network_security_group_id = azurerm_network_security_group.passthru_nsg.id

    ip_configuration {
        name                          = "nuke-nic-config"
        subnet_id                     = var.rsgSubnetId
        private_ip_address            = var.passthruIp
        private_ip_address_allocation = "static"
    }

    tags = {
        environment = var.envTag
    }
}

# Create virtual machine
resource "azurerm_virtual_machine" "passthru_vm" {
    name                  = "passthru"
    location              = var.rsgLocation
    resource_group_name   = var.rsgName
    vm_size               = var.passthruSize
    network_interface_ids = [ azurerm_network_interface.passthru_nic.id ]

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04-LTS"
        version   = "latest"
    }

    storage_os_disk {
        name              = "passthru-os-disk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    delete_os_disk_on_termination = true

    os_profile {
        computer_name  = "passthru"
        admin_username = var.login
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/${var.login}/.ssh/authorized_keys"
            key_data = var.sshPublicKey
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = var.rsgDiagSAEndpoint
    }

    tags = {
        environment = var.envTag
    }
}

locals {
    passthru_ansible_vars = {
        USER                = var.login
        BOX_IP              = azurerm_network_interface.passthru_nic.private_ip_address
        HOME                = "/usr/local/${var.login}"
        ingressIp           = var.ingressIp
        mongo1Ip            = var.mongo1Ip
        mongo2Ip            = var.mongo2Ip
        mongo3Ip            = var.mongo3Ip
        isSharedService     = var.isSharedService
        proxyServerName     = var.proxyServerName
        classCPlusOffset    = var.classCPlusOffset
        rootCertificate     = "../../../${var.rootCertificate}"
        sslCertificate      = "../../../${var.sslCertificate}"
        sslCertificateKey   = "../../../${var.sslCertificateKey}"
    }

    passthru_local_ansible_vars = {
        resourceName        = var.rsgName
        classCPlusOffset    = var.classCPlusOffset
        fluentdHost         = var.fluentdHost
        fluentdPort         = var.fluentdPort
        jumpIp              = var.jumpIp
        login               = var.login
        passthruIp          = azurerm_network_interface.passthru_nic.private_ip_address
        sshPrivateKeyFile   = "../../../${var.sshPrivateKeyFile}"
    }
}

resource "local_file" "passthru_secrets" {
    content     = jsonencode(local.passthru_ansible_vars)
    filename    = "${var.deploymentDir}/${var.passthruSecretsFile}"
}

resource "local_file" "passthru_local_secrets" {
    content     = jsonencode(local.passthru_local_ansible_vars)
    filename    = "${var.deploymentDir}/${var.passthruLocalSecretsFile}"
}

# Create the provisoner
resource "null_resource" "passthru_resource" {
    triggers = {
        passthru-id = azurerm_virtual_machine.passthru_vm.id
    }

    provisioner "local-exec" {
        working_dir = "${var.deploymentDir}/${var.projectsDir}/passthru"
        command= "./run_ansible.sh ${var.login} ${var.deploymentDir}/${var.sshPrivateKeyFile} ${var.deploymentDir}/${var.passthruSecretsFile} ${var.deploymentDir}/${var.passthruLocalSecretsFile}"
    }
}
