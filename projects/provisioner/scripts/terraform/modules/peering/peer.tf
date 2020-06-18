# #######################################################
#  Create a peer to the shared services deployment
resource "azurerm_virtual_network_peering" "outgoing" {
  name                         = "to-shared"
  resource_group_name          = "${var.rsgName}"
  virtual_network_name         = "${var.vNetName}"
  remote_virtual_network_id    = "${var.sharedVNetId}"
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "incoming" {
  name                         = "to-${var.rsgName}"
  resource_group_name          = "${var.sharedGroupName}"
  virtual_network_name         = "${var.sharedVNetName}"
  remote_virtual_network_id    = "${var.vNetId}"
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
