variable "rsgLocation" {
  type = string
}

variable "rsgName" {
  type = string
}

variable "classCPlus" {
  type = string
}

variable "classCPlusOffset" {
  type = string
}

variable "passthruIp" {
  type = string
}

variable "fluentdDest" {
  type = string
}

variable "envTag" {
  type = string
}

variable "rsgSubnetId" {
  type = string
}

variable "passthruSize" {
  type = string
  default = "Standard_DS11_v2"
}

variable "login" {
  type = string
}

variable "sshPublicKey" {
  type = string
}

variable "rsgDiagSAEndpoint" {
  type = string
}

variable "jumpIp" {
  type = string
}

variable "rootCertificate" {
  type = string
}

variable "sslCertificate" {
  type = string
}

variable "sslCertificateKey" {
  type = string
}

variable "sshPrivateKeyFile" {
  type = string
}

variable "ingressIp" {
  type = string
}

variable "isSharedService" {
  type = string
}

variable "proxyServerName" {
  type = string
}

variable "fluentdHost" {
  type = string
  default = "10.1.6.5"
}

variable "fluentdPort" {
  type = string
  default = "24224"
}

variable "mongo1Ip" {
  type = string
}

variable "mongo2Ip" {
  type = string
}

variable "mongo3Ip" {
  type = string
}

variable "passthruSecretsFile" {
  type = string
}

variable "passthruLocalSecretsFile" {
  type = string
}

variable "deploymentDir" {
  type = string
}

variable "projectsDir" {
  type = string
}
