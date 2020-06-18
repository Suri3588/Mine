variable "gitHash" {
  type = "string"
  default = "needs some work"
}

variable "login" {
  type = "string"
  default = "ciuser"
}

variable "envTag" {
  type = "string"
  default = "CI-CD"
}

variable "resourceName" {
  type = "string"
  default = "EngBuildInfrastructure"
}

variable "vaultName" {
  type = "string"
  default = "NucleusBuildVault"
}

variable "vaultAdminUser" {
  type = "string"
  default = "dreich@nucleushealth.onmicrosoft.com"
}

variable "sshPublicKey" {
  type = "string"
}

variable "sshPrivateKeyFile" {
  type = "string"
  default = "user_rsa"
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
variable "jenkinsSvcAPIKey" {
  type = "string"
}

variable "devSubscriptionId" {
  type = "string"
  default = "510dd537-5356-41c7-b31d-65d9a93016e1"
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

variable "jenkinsSvcObjId" {
  type = "string"
}