locals {
  mongo_ips = [ "${var.classCPlusOffset}.10", "${var.classCPlusOffset}.11", "${var.classCPlusOffset}.12" ]
}

# Generate the mongo passwords
resource "random_string" "mongoPassword" {
  length = 32
  special = false
}

resource "random_string" "mongoAdminPassword" {
  length = 32
  special = false
}

resource "random_string" "mongoExporterPassword" {
  length = 32
  special = false
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "mongo_nsg" {
    name                = "mongo-nsg"
    location            = "${var.rsgLocation}"
    resource_group_name = "${var.rsgName}"

    security_rule {
        name                       = "mongo"
        priority                   = 2001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "27017"
        source_address_prefix      = "${var.classCPlus}.0/21"
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
        source_address_prefix      = "${var.classCPlus}.4/32"
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
        source_address_prefix      = "${var.classCPlusOffset}.5/32"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "prometheus-mongo"
        priority                   = 2011
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "9216"
        source_address_prefix      = "${var.classCPlusOffset}.5/32"
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
        environment = "${var.envTag}"
    }
}

# Create the mongo specific networking stuff
resource "azurerm_network_interface" "mongo_nic" {
    count               = "${var.mongoCount}"
    name                = "mongo-nic-${count.index}"
    location            = "${var.rsgLocation}"
    resource_group_name = "${var.rsgName}"
    network_security_group_id = "${azurerm_network_security_group.mongo_nsg.id}"

    ip_configuration {
        name =                          "mongo-ipconf-${count.index}"
        subnet_id =                     "${var.rsgSubnetId}"
        private_ip_address_allocation = "static"
        private_ip_address            = "${element(local.mongo_ips, count.index)}"
    }
}

# Create an availability set for the mongo servers
resource "azurerm_availability_set" "mongo_avail" {
    name                = "mongo-avail"
    location            = "${var.rsgLocation}"
    resource_group_name = "${var.rsgName}"
    managed             = true
}

resource "azurerm_managed_disk" "mongodatadisk" {
    count                 = "${var.mongoCount}"
    name                  = "mongo-data-disk-${count.index}"
    location              = "${var.rsgLocation}"
    resource_group_name   = "${var.rsgName}"
    storage_account_type  = "Standard_LRS"
    create_option         = "Empty"
    disk_size_gb          = "${var.mongoDiskSize}"

    tags = {
        environment = "${var.envTag}"
    }
}

# Create virtual machines
resource "azurerm_virtual_machine" "mongo" {
    count                 = "${var.mongoCount}"
    name                  = "mongo-${count.index}"
    location              = "${var.rsgLocation}"
    resource_group_name   = "${var.rsgName}"
    network_interface_ids = ["${element(azurerm_network_interface.mongo_nic.*.id, count.index)}"]
    vm_size               = "Standard_DS11_v2"

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04-LTS"
        version   = "latest"
    }

    storage_os_disk {
        name              = "mongo-os-disk-${count.index}"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    delete_os_disk_on_termination = true

    storage_data_disk {
        name              = "${element(azurerm_managed_disk.mongodatadisk.*.name, count.index)}"
        managed_disk_id   = "${element(azurerm_managed_disk.mongodatadisk.*.id, count.index)}"
        create_option     = "Attach"
        disk_size_gb      = "${element(azurerm_managed_disk.mongodatadisk.*.disk_size_gb, count.index)}"
        lun               = 0
    }

    delete_data_disks_on_termination = false

    os_profile {
        computer_name  = "mongo-${count.index}"
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
}

# Create the provisioner
resource "null_resource" "mongo_platform" {
    triggers = {
        mongo-1-id = "${element(azurerm_virtual_machine.mongo.*.id, 1)}"
    }

    provisioner "local-exec" {
        command= "${path.module}/run_ansible.sh ${var.environment} ${var.classCPlus} ${var.jumpIp} ${var.login} ${var.sshPrivateKeyFile} ${random_string.mongoAdminPassword.result} ${random_string.mongoPassword.result} ${var.dbName} ${var.mongoVersion} ${var.classCPlusOffset} ${var.fluentdHost} ${var.fluentdPort} ${var.rsgName} ${random_string.mongoExporterPassword.result}"
    }
}
