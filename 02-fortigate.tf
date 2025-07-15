##############################################################################################################
#
# FortiGate Active/Active Load Balanced pair of standalone FortiGate VMs for resilience and scale
# Terraform deployment template for Microsoft Azure
#
##############################################################################################################

resource "azurerm_availability_set" "fgtavset" {
  name                = "${var.prefix}-fgt-availabilityset"
  location            = var.location
  managed             = true
  resource_group_name = azurerm_resource_group.resourcegroup.name
  platform_fault_domain_count = 2  # Explicitly set to 2 for regions that don't support 3
}

resource "azurerm_network_security_group" "fgtnsg" {
  name                = "${var.prefix}-fgt-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.resourcegroup.name
}

resource "azurerm_network_security_rule" "fgtnsgallowallout" {
  name                        = "AllowAllOutbound"
  resource_group_name         = azurerm_resource_group.resourcegroup.name
  network_security_group_name = azurerm_network_security_group.fgtnsg.name
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
}

resource "azurerm_network_security_rule" "fgtnsgallowallin" {
  name                        = "AllowAllInbound"
  resource_group_name         = azurerm_resource_group.resourcegroup.name
  network_security_group_name = azurerm_network_security_group.fgtnsg.name
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
}

# =============================================
# New External Internal Load Balancer (external-ilb)
# =============================================
resource "azurerm_lb" "external_ilb" {
  name                = "${var.prefix}-ExternalILB"
  location            = var.location
  resource_group_name = azurerm_resource_group.resourcegroup.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "${var.prefix}-ExternalILB-FE"
    subnet_id                     = azurerm_subnet.subnet1.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_lb_backend_address_pool" "external_ilb_backend" {
  loadbalancer_id = azurerm_lb.external_ilb.id
  name            = "BackEndPool"
}

resource "azurerm_lb_probe" "external_ilb_probe" {
  loadbalancer_id     = azurerm_lb.external_ilb.id
  name                = "lbprobe"
  port                = 8008
  interval_in_seconds = 5
  number_of_probes    = 2
  protocol            = "Tcp"
}

resource "azurerm_lb_rule" "external_ilb_rule" {
  loadbalancer_id                = azurerm_lb.external_ilb.id
  name                           = "ExternalILBRule"
  protocol                       = "All"
  frontend_port                  = 0
  backend_port                   = 0
  frontend_ip_configuration_name = "${var.prefix}-ExternalILB-FE"
  probe_id                       = azurerm_lb_probe.external_ilb_probe.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.external_ilb_backend.id]
}

# =============================================
# Original Internal Load Balancer (ILB) - PRESERVED
# =============================================
resource "azurerm_lb" "ilb" {
  name                = "${var.prefix}-InternalLoadBalancer"
  location            = var.location
  resource_group_name = azurerm_resource_group.resourcegroup.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "${var.prefix}-ILB-PIP"
    subnet_id                     = azurerm_subnet.subnet2.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_lb_backend_address_pool" "ilbbackend" {
  loadbalancer_id = azurerm_lb.ilb.id
  name            = "BackEndPool"
}

resource "azurerm_lb_probe" "ilbprobe" {
  loadbalancer_id     = azurerm_lb.ilb.id
  name                = "lbprobe"
  port                = 8008
  interval_in_seconds = 5
  number_of_probes    = 2
  protocol            = "Tcp"
}

resource "azurerm_lb_rule" "lb_haports_rule" {
  loadbalancer_id                = azurerm_lb.ilb.id
  name                           = "lb_haports_rule"
  protocol                       = "All"
  frontend_port                  = 0
  backend_port                   = 0
  frontend_ip_configuration_name = "${var.prefix}-ILB-PIP"
  probe_id                       = azurerm_lb_probe.ilbprobe.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.ilbbackend.id]
}

# =============================================
# Network Interfaces (Updated with 4 NICs per FGT)
# =============================================
resource "azurerm_network_interface" "fgtifc1" {
  count                         = var.FGT_COUNT
  name                          = "${var.prefix}-fgt-${count.index}-nic1"
  location                      = azurerm_resource_group.resourcegroup.location
  resource_group_name           = azurerm_resource_group.resourcegroup.name
  ip_forwarding_enabled         = true
  accelerated_networking_enabled = var.FGT_ACCELERATED_NETWORKING

  ip_configuration {
    name                          = "interface1"
    subnet_id                     = azurerm_subnet.subnet1.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "fgtifc1" {
  count                     = var.FGT_COUNT
  network_interface_id      = element(azurerm_network_interface.fgtifc1.*.id, count.index)
  network_security_group_id = azurerm_network_security_group.fgtnsg.id
}

resource "azurerm_network_interface_backend_address_pool_association" "fgtifc1_external_ilb" {
  count                   = var.FGT_COUNT
  network_interface_id    = element(azurerm_network_interface.fgtifc1.*.id, count.index)
  ip_configuration_name   = "interface1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.external_ilb_backend.id
}

resource "azurerm_network_interface" "fgtifc2" {
  count                = var.FGT_COUNT
  name                 = "${var.prefix}-fgt-${count.index}-nic2"
  location             = azurerm_resource_group.resourcegroup.location
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  ip_forwarding_enabled = true
  accelerated_networking_enabled = var.FGT_ACCELERATED_NETWORKING

  ip_configuration {
    name                          = "interface1"
    subnet_id                     = azurerm_subnet.subnet2.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "fgtifc2" {
  count                     = var.FGT_COUNT
  network_interface_id      = element(azurerm_network_interface.fgtifc2.*.id, count.index)
  network_security_group_id = azurerm_network_security_group.fgtnsg.id
}

resource "azurerm_network_interface_backend_address_pool_association" "fgtifc2_ilbbackend" {
  count                   = var.FGT_COUNT
  network_interface_id    = element(azurerm_network_interface.fgtifc2.*.id, count.index)
  ip_configuration_name   = "interface1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.ilbbackend.id
}

# New FGSP Interface (NIC3)
resource "azurerm_network_interface" "fgtifc3" {
  count                = var.FGT_COUNT
  name                 = "${var.prefix}-fgt-${count.index}-nic3"
  location             = azurerm_resource_group.resourcegroup.location
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  ip_forwarding_enabled = true
  accelerated_networking_enabled = var.FGT_ACCELERATED_NETWORKING

  ip_configuration {
    name                          = "interface1"
    subnet_id                     = azurerm_subnet.subnet4.id
    private_ip_address_allocation = "Dynamic"
  }
}

# New Management Interface (NIC4) with Public IP
resource "azurerm_public_ip" "fgtmgmtpip" {
  count               = var.FGT_COUNT
  name                = "${var.prefix}-fgt-${count.index}-mgmt-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.resourcegroup.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "fgtifc4" {
  count                = var.FGT_COUNT
  name                 = "${var.prefix}-fgt-${count.index}-nic4"
  location             = azurerm_resource_group.resourcegroup.location
  resource_group_name  = azurerm_resource_group.resourcegroup.name

  ip_configuration {
    name                          = "interface1"
    subnet_id                     = azurerm_subnet.subnet5.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = element(azurerm_public_ip.fgtmgmtpip.*.id, count.index)
  }
}

# =============================================
# FortiGate VMs (Updated with 4 NICs)
# =============================================
resource "azurerm_linux_virtual_machine" "fgtvm" {
  count                 = var.FGT_COUNT
  name                  = "${var.prefix}-fgt-${count.index}"
  location              = azurerm_resource_group.resourcegroup.location
  resource_group_name   = azurerm_resource_group.resourcegroup.name
  network_interface_ids = [
    element(azurerm_network_interface.fgtifc1.*.id, count.index),
    element(azurerm_network_interface.fgtifc2.*.id, count.index),
    element(azurerm_network_interface.fgtifc3.*.id, count.index),
    element(azurerm_network_interface.fgtifc4.*.id, count.index)
  ]
  size                  = var.fgt_vmsize
  availability_set_id   = azurerm_availability_set.fgtavset.id

  identity {
    type = "SystemAssigned"
  }

  source_image_reference {
    publisher = "fortinet"
    offer     = "fortinet_fortigate-vm_v5"
    sku       = var.FGT_IMAGE_SKU
    version   = var.FGT_VERSION
  }

  plan {
    publisher = "fortinet"
    product   = "fortinet_fortigate-vm_v5"
    name      = var.FGT_IMAGE_SKU
  }

  os_disk {
    name                 = "${var.prefix}-fgt-${count.index}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_username                  = var.username
  admin_password                  = var.password
  disable_password_authentication = false
  custom_data = base64encode(templatefile("${path.module}/customdata.tpl", {
  fgt_vm_name           = "${var.prefix}-fgt-${count.index}"
  fgt_license_file      = "${var.FGT_BYOL_LICENSE_FILE[tostring(count.index)]}"
  fgt_license_fortiflex = "${var.FGT_BYOL_FORTIFLEX_LICENSE_TOKEN[tostring(count.index)]}"
  fgt_username          = var.username
  fgt_ssh_public_key    = var.FGT_SSH_PUBLIC_KEY_FILE
  fgt_external_ipaddr   = azurerm_network_interface.fgtifc1[count.index].private_ip_address
  fgt_external_mask     = cidrnetmask(var.subnet["0"])
  fgt_external_gw       = cidrhost(var.subnet["0"], 1)
  fgt_internal_ipaddr   = azurerm_network_interface.fgtifc2[count.index].private_ip_address
  fgt_internal_mask     = cidrnetmask(var.subnet["1"])
  fgt_internal_gw       = cidrhost(var.subnet["1"], 1)
  fgt_fgsp_ipaddr       = azurerm_network_interface.fgtifc3[count.index].private_ip_address
  fgt_fgsp_mask         = cidrnetmask(var.subnet["3"])  # Subnet4 is FGSP
  fgt_fgsp_gw           = cidrhost(var.subnet["3"], 1)
  fgt_mgmt_ipaddr       = azurerm_network_interface.fgtifc4[count.index].private_ip_address
  fgt_mgmt_mask         = cidrnetmask(var.subnet["4"])  # Subnet5 is MGMT
  fgt_mgmt_gw           = cidrhost(var.subnet["4"], 1)
  fgt_protected_net     = var.subnet["2"]  # Changed index to match your subnet map
  vnet_network          = var.vnet
  fgt_fgsp_group_id   = "100"  # Same for both FortiGates Locally Significat
  fgt_fgsp_member_id  = count.index + 1  # 1 for FGT1, 2 for FGT2
  fgt_fgsp_peer_ip    = count.index == 0 ? azurerm_network_interface.fgtifc3[1].private_ip_address : azurerm_network_interface.fgtifc3[0].private_ip_address
}))

  boot_diagnostics {
    storage_account_uri = null
  }

  tags = var.fortinet_tags
}

# =============================================
# Data Disks and Outputs
# =============================================
resource "azurerm_managed_disk" "fgtvm-datadisk" {
  count                = var.FGT_COUNT
  name                 = "${var.prefix}-fgt-${count.index}-datadisk"
  location             = azurerm_resource_group.resourcegroup.location
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 50
}

resource "azurerm_virtual_machine_data_disk_attachment" "fgtvm-datadisk-attach" {
  count              = var.FGT_COUNT
  managed_disk_id    = element(azurerm_managed_disk.fgtvm-datadisk.*.id, count.index)
  virtual_machine_id = element(azurerm_linux_virtual_machine.fgtvm.*.id, count.index)
  lun                = 0
  caching            = "ReadWrite"
}

# Output now shows management IPs instead of ELB IP
output "fgt_mgmt_ips" {
  value = {
    fgt_a = azurerm_public_ip.fgtmgmtpip[0].ip_address
    fgt_b = azurerm_public_ip.fgtmgmtpip[1].ip_address
  }
}