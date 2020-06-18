locals {
  subscriptions = {
    dev = "510dd537-5356-41c7-b31d-65d9a93016e1"
    dev2 = "02b0c8a5-ded5-40d5-96a2-35a9665a56d0"
    prod = "c5737d32-09d4-4cae-bf13-ad5dd93cf0c4"
  }
  currdir = "${basename(abspath(path.root))}"
}

output "id" {
  value = "${local.subscriptions[local.currdir]}"
  description = "ID of the subscription that corresponds to the current directory"
}

output "environment" {
  value = "${local.currdir}"
  description = "The name of the environment inferred from the directory"
}
