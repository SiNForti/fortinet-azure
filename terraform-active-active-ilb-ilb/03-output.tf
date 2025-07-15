##############################################################################################################
#
# FortiGate Active/Active Load Balanced pair of standalone FortiGate VMs for resilience and scale
# Terraform deployment template for Microsoft Azure
#
# Output summary of deployment
#
##############################################################################################################

output "deployment_summary" {
  value = templatefile("${path.module}/summary.tpl", {
    username                     = var.username
    location                     = var.location
    fgt_a_mgmt_ip                = azurerm_public_ip.fgtmgmtpip[0].ip_address
    fgt_b_mgmt_ip                = azurerm_public_ip.fgtmgmtpip[1].ip_address
    fgt_a_private_ip_address_ext = azurerm_network_interface.fgtifc1[0].private_ip_address
    fgt_a_private_ip_address_int = azurerm_network_interface.fgtifc2[0].private_ip_address
    fgt_b_private_ip_address_ext = azurerm_network_interface.fgtifc1[1].private_ip_address
    fgt_b_private_ip_address_int = azurerm_network_interface.fgtifc2[1].private_ip_address
    external_ilb_ip              = azurerm_lb.external_ilb.frontend_ip_configuration[0].private_ip_address
    internal_ilb_ip              = azurerm_lb.ilb.frontend_ip_configuration[0].private_ip_address
  })
}

output "fgt_a_mgmt_public_ip" {
  description = "FortiGate A management public IP"
  value       = azurerm_public_ip.fgtmgmtpip[0].ip_address
}

output "fgt_b_mgmt_public_ip" {
  description = "FortiGate B management public IP"
  value       = azurerm_public_ip.fgtmgmtpip[1].ip_address
}

output "external_ilb_private_ip" {
  description = "External Internal Load Balancer private IP"
  value       = azurerm_lb.external_ilb.frontend_ip_configuration[0].private_ip_address
}

output "internal_ilb_private_ip" {
  description = "Original Internal Load Balancer private IP"
  value       = azurerm_lb.ilb.frontend_ip_configuration[0].private_ip_address
}

output "fgt_interfaces" {
  description = "All FortiGate interface IP addresses"
  value = {
    fgt_a = {
      ext   = azurerm_network_interface.fgtifc1[0].private_ip_address
      int   = azurerm_network_interface.fgtifc2[0].private_ip_address
      fgsp  = azurerm_network_interface.fgtifc3[0].private_ip_address
      mgmt  = azurerm_network_interface.fgtifc4[0].private_ip_address
    }
    fgt_b = {
      ext   = azurerm_network_interface.fgtifc1[1].private_ip_address
      int   = azurerm_network_interface.fgtifc2[1].private_ip_address
      fgsp  = azurerm_network_interface.fgtifc3[1].private_ip_address
      mgmt  = azurerm_network_interface.fgtifc4[1].private_ip_address
    }
  }
}