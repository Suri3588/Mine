variable "rsgName" {
  type = "string"
}
variable "rsgLocation" {
  type = "string"
}
variable "rsgDiagSAEndpoint" {
  type = "string"
}
variable "primaryLocation" {
  type = "string"
}
variable "rsgSubnetId" {
  type = "string"
}
variable "gitHash" {
  type = "string"
}

variable "login" {
  type = "string"
  default = "ciuser"
}

variable "envTag" {
  type = "string"
}

variable "vaultAdminUser" {
  type = "string"
}
variable "buildVaultId" {

}

variable "sshPublicKey" {
  type = "string"
}

variable "sshPrivateKeyFile" {
  type = "string"
}

variable "dnsName" {
  type = "string"
}

variable "serverName" {
  type = "string"
  default = "prod-cicd.nucleushealthdev.io"
}

variable "classCPlus" {
  type = "string"
  default = "10.4.0"
}

variable "githubProdPwd" {
  type = "string"
}

variable "githubProdUser" {
  type = "string"
}

variable "nucleusBuilderPwd" {
  type = "string"
}
variable "jiraPwd" {
  type = "string"
}

variable "jiraUsername" {
  type = "string"
}

variable "jenkinsAadTenantId" {
  type = "string"
}
variable "jenkinsAadClientId" {
  type = "string"
}
variable "jenkinsAadAPIKey" {
  type = "string"
}

variable "jenkinsSvcTenantId" {
  type = "string"
}
variable "jenkinsSvcClientId" {
  type = "string"
}

variable "jenkinsSvcObjId" {
  type = "string"
}
variable "jenkinsSvcAPIKey" {
  type = "string"
}

variable "devSubscriptionId" {
  type = "string"
}
variable "jenkinsDevSvcTenantId" {
  type = "string"
}
variable "jenkinsDevSvcClientId" {
  type = "string"
}
variable "jenkinsDevSvcAPIKey" {
  type = "string"
}