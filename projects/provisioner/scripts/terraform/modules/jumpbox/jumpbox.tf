# Create public IPs
resource "azurerm_public_ip" "jump_public_ip" {
    name                = "jump-public-ip"
    location            = var.rsgLocation
    resource_group_name = var.rsgName
    allocation_method   = "Static"

    tags = {
        environment = var.envTag
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "jump_nsg" {
    name                = "jump-security"
    location            = var.rsgLocation
    resource_group_name = var.rsgName

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

# Create the mongo specific networking stuff
resource "azurerm_network_interface" "jump_nic" {
    name                      = "jump-nic1"
    location                  = var.rsgLocation
    resource_group_name       = var.rsgName
    network_security_group_id = azurerm_network_security_group.jump_nsg.id

    ip_configuration {
        name                          = "jump-ipconf"
        subnet_id                     = var.rsgSubnetId
        public_ip_address_id          = azurerm_public_ip.jump_public_ip.id
        private_ip_address            = "${var.classCPlusOffset}.105"
        private_ip_address_allocation = "static"
    }
}

locals {
    jumpbox_ansible_vars = {
        pm2_user = var.login
        HOME = "/home/${var.login}"
        NVM_DIR = "/home/${var.login}/.nvm"
        NVM_VERSION = var.nvmVersion
        NODE_VERSION = var.nodeVersion
    }
}

resource "local_file" "jumpbox_secrets" {
    content     = jsonencode(local.jumpbox_ansible_vars)
    filename    = "${var.deploymentDir}/${var.jumpboxSecretsFile}"
}

# Create virtual machines
resource "azurerm_virtual_machine" "jump" {
    name                  = "jump"
    location              = var.rsgLocation
    resource_group_name   = var.rsgName
    network_interface_ids = [ azurerm_network_interface.jump_nic.id ]
    vm_size               = "Standard_DS1_v2"

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04-LTS"
        version   = "latest"
    }

    storage_os_disk {
        name              = "jump-os-disk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    delete_os_disk_on_termination    = true

    os_profile {
        computer_name  = "jump"
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

    provisioner "local-exec" {
      working_dir = "${var.deploymentDir}/${var.projectsDir}/jumpbox"
      command = "./run_ansible.sh ${var.login} ${var.deploymentDir}/${var.sshPrivateKeyFile} ${var.deploymentDir}/${var.jumpboxSecretsFile}"
    }
}
