variable "classCPlus" {
  type = string
}

variable "classCPlusOffset" {
  type = string
}

variable "dbName" {
  type = string
}

variable "environment" {
  type = string
}

variable "envTag" {
  type = string
  default = "KubeGroup"
}

variable "fluentdHost" {
  type = string
  default = "10.1.6.5"
}

variable "fluentdPort" {
  type = string
  default = "24224"
}

variable "login" {
  type = string
  default = "nucleus"
}

variable "mongoCount" {
  type = string
  default = "3"
}

variable "mongoDiskSize" {
  type = string
  default = "128"
}

variable "mongoVersion" {
  type = string
  default = "4.0"
}

variable "jumpIp" {
  type = string
}

variable "rsgDiagSAEndpoint" {
  type = string
}

variable "rsgLocation" {
  type = string
}

variable "rsgName" {
  type = string
}

variable "rsgSubnetId" {
  type = string
}

variable "sshPublicKey" {
  type = string
}

variable "sshPrivateKeyFile" {
  type = string
}
