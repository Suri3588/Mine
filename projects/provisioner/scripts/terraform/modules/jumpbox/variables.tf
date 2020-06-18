variable "rsgLocation" {
  type = string
}

variable "rsgName" {
  type = string
}

variable "envTag" {
  type = string
}

variable "rsgSubnetId" {
  type = string
}

variable "classCPlusOffset" {
  type = string
}

variable "login" {
  type = string
  default = "nucleus"
}

variable "nodeVersion" {
  type = string
  default = "10.13.0"
}

variable "nvmVersion" {
  type = string
  default = "0.33.8"
}

variable "sshPublicKey" {
  type = string
}

variable "rsgDiagSAEndpoint" {
  type = string
}

variable "jumpboxSecretsFile" {
  type = string
}

variable "sshPrivateKeyFile" {
  type = string
}

variable "deploymentDir" {
  type = string
}

variable "projectsDir" {
  type = string
}
