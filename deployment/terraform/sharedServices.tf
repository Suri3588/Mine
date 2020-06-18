module "resgroup" {
  source          = "../modules/resgroup"
  
  envTag          = "shared-services-qe Group"
  resourceName    = "shared-services-qe"
  classCPlus      = var.classCPlus
  primaryLocation = var.primaryLocation
}

resource "random_id" "passthru_jumpbox_boot_prefix" {
  byte_length = 9
}

resource "azurerm_storage_account" "passthru_jumpbox_boot" {
  name =                      "${random_id.passthru_jumpbox_boot_prefix.hex}boot"
  resource_group_name =       module.resgroup.name
  location =                  module.resgroup.location
  account_tier =              "Standard"
  account_replication_type =  "GRS"
}

module "publicIp" {
  source = "../modules/publicIp"

  rsgName              = "shared-services-qe"
  dnsPrefix            = "shared-services-qe"
  rsgLocation          = var.primaryLocation
}

module "kubegroup" {
  source = "../modules/kubegroup"

  # THE FOLLOWING VALUES ARE REQUIRED BY TERRAFORM FOR CLUSTER CREATION, BUT ARE ALSO SUBJECT TO CHANGE OVER TIME.
  # UNFORTUNATELY, TERRAFORM REQUIRES DESTROYING AND RECREATING THE CLUSTER WHENEVER THESE VALUES CHANGE.
  # BECAUSE OF THIS WE HAVE MARKED THE ATTRIBUTES THAT USE THESE VARIABLES TO BE IGNORED IN THE MODULE FOR UPDATES.
  # UPDATING OF THESE VARIABLES WILL BE PERFORMED VIA AZURE CLI IN OUR UPDATE SCRIPTS RATHER THAN BY TERRAFORM.
  # SO WHILE THESE VALUES ARE CORRECT AT THE TIME OF INITIAL CREATION, THEY MAY BECOME STALE AND ARE NOT TO BE CONSIDERED CORRECT
  # THE SOURCE OF TRUTH FOR THESE VALUES ARE THE CORROSPONDING SECRETS ENTRIES IN THE KEY VAULT, AND ARE SET AS ENVIRONMENT VARIABLES FOR UPDATES
  akcPrincipal         = "ade06026-4420-4aaf-b9b0-4703d0ff882c"
  akcPrincipalPassword = "05c1dc56-5e07-4fd0-bf79-3175a66c0417"
  aksAadClientId       = "57f5cb27-1bc6-4b39-aeb6-f8f61e12a6c0"
  aksAadServerId       = "7217e351-9292-4986-9b52-097b3e0e7393"
  aksAadServerSecret   = "HBz7YGY45lRp:uoy-[o8HzrRv*c7ae*T"
  aksAadTenantId       = "418b0446-911f-42b4-8c8c-c4e27a1be63c"

  dnsPrefix            = "shared-services-qe"
  kubernetes_version   = var.kubernetes_version
  clusterAdminGuid     = var.clusterAdminGuid
  clusterViewerGuid    = var.clusterViewerGuid
  regaksPublicKey      = var.regaksPublicKey
  rsgName              = module.resgroup.name
  publicIpRsgId        = module.publicIp.publicIpRsgId
  rsgLocation          = module.resgroup.location
  rsgSubnetId          = module.resgroup.subnetId
  vnetId               = module.resgroup.vNetId

  dependencies = [ module.publicIp.depended_on ]

  additional_node_pools = {
    esdatanodes = {
      vm_size                        = "Standard_DS13_v2"
      node_os                        = "Linux"
      zones                          = null
      max_pods                       = 30
      os_disk_size_gb                = 128
      taints                         = [ "dedicated=esdata:NoSchedule" ]
      node_count                     = 2
      cluster_auto_scaling           = false
      cluster_auto_scaling_min_count = null
      cluster_auto_scaling_max_count = null
    }
    esothernodes = {
      vm_size                        = "Standard_DS11_v2"
      node_os                        = "Linux"
      zones                          = null
      max_pods                       = 30
      os_disk_size_gb                = 128
      taints                         = [ "dedicated=esother:NoSchedule" ]
      node_count                     = 4
      cluster_auto_scaling           = false
      cluster_auto_scaling_min_count = null
      cluster_auto_scaling_max_count = null
    }
    monpool = {
      node_count                     = 2
      vm_size                        = "Standard_DS3_v2"
      node_os                        = "Linux"
      zones                          = null
      max_pods                       = 30
      os_disk_size_gb                = 128
      taints                         = null
      cluster_auto_scaling           = false
      cluster_auto_scaling_min_count = null
      cluster_auto_scaling_max_count = null
    }
  }
}

module "jumpbox" {
  source 	       = "../modules/jumpbox"

  nvmVersion           = "0.33.8"
  nodeVersion          = "10.13.0"
  envTag               = "shared-services-qe Jump Box"

  login                = var.login
  classCPlusOffset     = var.classCPlusOffset
  jumpboxSecretsFile   = var.jumpboxSecretsFile
  deploymentDir        = var.deploymentDir
  projectsDir          = var.projectsDir
  sshPublicKey         = var.sshPublicKey
  sshPrivateKeyFile    = var.sshPrivateKeyFile
  rsgDiagSAEndpoint    = module.resgroup.diagSAEndpoint
  rsgName              = module.resgroup.name
  rsgLocation          = module.resgroup.location
  rsgSubnetId          = module.resgroup.subnetId
}

module "passthru" {
  source 		    = "../modules/passthru"

  passthruSize              = "Standard_DS11_v2"
  envTag                    = "shared-services-qe Passthru"
  passthruIp                = "${var.classCPlusOffset}.5"
  fluentdDest		            = "10.1.6.5"
  mongo1Ip                  = ""
  mongo2Ip                  = ""
  mongo3Ip                  = ""
  login                     = var.login
  classCPlus                = var.classCPlus
  classCPlusOffset          = var.classCPlusOffset
  ingressIp                 = var.ingressIp
  isSharedService           = var.isSharedService
  deploymentDir             = var.deploymentDir
  projectsDir               = var.projectsDir
  passthruSecretsFile       = var.passthruSecretsFile
  passthruLocalSecretsFile  = var.passthruLocalSecretsFile
  sshPublicKey              = var.sshPublicKey
  sshPrivateKeyFile         = var.sshPrivateKeyFile
  sslCertificate            = var.sslCertificate
  sslCertificateKey         = var.sslCertificateKey
  proxyServerName           = var.proxyServerName
  rootCertificate           = var.rootCertificate
  jumpIp                    = module.jumpbox.jumpIp
  rsgDiagSAEndpoint         = module.resgroup.diagSAEndpoint
  rsgName                   = module.resgroup.name
  rsgLocation               = module.resgroup.location
  rsgSubnetId               = module.resgroup.subnetId
}

resource "azurerm_application_insights" "app_insights" {
  name                = "app-insights"
  application_type    = "Node.JS"
  resource_group_name = module.resgroup.name
  location            = module.resgroup.location
}

resource "null_resource" "shared_services_dns" {
  depends_on = [ module.kubegroup ]
  triggers = {
    path  = path.module
  }

  provisioner "local-exec" {
    working_dir = self.triggers.path
    command= "../projects/logging/update-shared-services-dns.sh shared-services-qe nucleushealthdev.io"
  }

  provisioner "local-exec" {
    working_dir = self.triggers.path
    command= "../projects/logging/remove-shared-services-dns.sh shared-services-qe nucleushealthdev.io"
    when = destroy
  }
}
