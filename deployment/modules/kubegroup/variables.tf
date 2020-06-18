variable "rsgLocation" {
  type = string
}

variable "rsgName" {
  type = string
}

variable "vnetId" {
  type = string
}

variable dnsPrefix {
  type = string
}

variable "regaksPublicKey" {
  type = string
}

variable "rsgSubnetId" {
  type = string
}

variable "akcPrincipal" {
  type = string
}

variable "akcPrincipalPassword" {
  type = string
}

variable "aksAadClientId" {
  type = string
}

variable "aksAadServerId" {
  type = string
}

variable "aksAadServerSecret" {
  type = string
}

variable "aksAadTenantId" {
  type = string
}

variable "clusterAdminGuid" {
  type = string
}

variable "clusterViewerGuid" {
  type = string
}

variable "dependencies" {
  type    = list
  default = []
}

variable "publicIpRsgId" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "additional_node_pools" {
  type = map(object({
    node_count                     = number
    vm_size                        = string
    zones                          = list(string)
    max_pods                       = number
    os_disk_size_gb                = number
    node_os                        = string
    taints                         = list(string)
    cluster_auto_scaling           = bool
    cluster_auto_scaling_min_count = number
    cluster_auto_scaling_max_count = number
  }))
}