variable "sshPublicKey" {
  type = "string"
}

variable "sshPrivateKeyFile" {
  type = "string"
  default = "user_rsa"
}

variable "envTag" {
  type = "string"
  default = "Testing"
}