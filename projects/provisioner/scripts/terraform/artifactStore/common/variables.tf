variable "envTag" {
  type = string
  default = "CI-CD"
}

variable "environment" {
  type = string
}

variable "registryReaderId" {
  type = string
}

variable "resourceName" {
  type = string
  default = "NucleusArtifactStore"
}

variable "primaryLocation" {
  type = string
  default = "Central US"
}