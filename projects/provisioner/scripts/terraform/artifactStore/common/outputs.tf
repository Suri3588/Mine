# Not sure we want a vault in the artifact store - there are no uses for it
# at the moment. But is we find one, uncomment this code.
# output "vaultid" {
#     value = "${module.keyvault.id}"
# }

# output "fullKeyPermissions" {
#   value = module.keyvault.fullKeyPermissions
# }

# output "fullSecretPermissions" {
#   value = module.keyvault.fullSecretPermissions
# }

# output "fullCertPermissions" {
#   value = module.keyvault.fullCertPermissions
# }