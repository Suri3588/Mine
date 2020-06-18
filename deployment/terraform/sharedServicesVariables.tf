variable "kubernetes_version" {
  type = string
  default = "1.14.8"
}

variable "classCPlus" {
  type = string
  default = "10.1.0"
}

variable "classCPlusOffset" {
  type = string
  default = "10.1.6"
}

variable "clusterAdminGuid" {
  type = string
}

variable "clusterViewerGuid" {
  type = string
}

variable "dbName" {
  type = string
  default = "kubegroup"
}

variable "dnsZone" {
  type = string
  default = "nucleushealthdev.io"
}

variable "failoverLocation" {
  type    = string
  default = "East US"
}

variable "ingressIp" {
  type = string
  default = "10.1.6.6"
}

variable "isSharedService" {
  type = string
  default = "true"
}

variable "login" {
  type = string
  default = "nucleus"
}

variable "proxyServerName" {
  type = string
  default = "10.1.6.5"
}

variable "primaryLocation" {
  type    = string
  default = "West US"
}

variable "regaksPublicKey" {
  type = string
}

variable "resourceName" {
  type    = string
  default = "registry"
}

variable "sshPublicKey" {
  type = string
}

variable "deploymentDir" {
  type = string
  description = "populated from the TF_VAR_deploymentDir environment variable set in extract-secrets.sh"
}

variable "projectsDir" {
  type = string
  default = "projects"
}

variable "passthruSecretsFile" {
  type = string
  default = "secretfiles/passthru.json"
}

variable "passthruLocalSecretsFile" {
  type = string
  default = "secretfiles/passthru-local.json"
}

variable "jumpboxSecretsFile" {
  type = string
  default = "secretfiles/jumpbox.json"
}

variable "rootCertificate" {
  type = string
  default = "secretfiles/root.crt"
}

variable "sshPrivateKeyFile" {
  type = string
  default = "secretfiles/ssh_rsa"
}

variable "sslCertificate" {
  type = string
  default = "secretfiles/ssl.crt"
}

variable "sslCertificateKey" {
  type = string
  default = "secretfiles/ssl.key"
}
