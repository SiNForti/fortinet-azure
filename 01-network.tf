##############################################################################################################
#
# FortiGate Active/Active Load Balanced pair of standalone FortiGate VMs for resilience and scale
# Terraform deployment template for Microsoft Azure
#
# Deployment of the virtual network
#
##############################################################################################################

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-VNET"
  address_space       = [var.vnet]
  location            = azurerm_resource_group.resourcegroup.location
  resource_group_name = azurerm_resource_group.resourcegroup.name
}

# External Subnet (now used by external-ilb)
resource "azurerm_subnet" "subnet1" {
  name                 = "${var.prefix}-SUBNET-FGT-EXTERNAL"
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet["0"]]
}

# Internal Subnet (used by original ilb)
resource "azurerm_subnet" "subnet2" {
  name                 = "${var.prefix}-SUBNET-FGT-INTERNAL"
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet["1"]]
}

# Protected Subnet A
resource "azurerm_subnet" "subnet3" {
  name                 = "${var.prefix}-SUBNET-PROTECTED-A"
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet["2"]]
}

# NEW: FGSP Subnet
resource "azurerm_subnet" "subnet4" {
  name                 = "${var.prefix}-SUBNET-FGSP"
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet["3"]]
}

# NEW: Management Subnet
resource "azurerm_subnet" "subnet5" {
  name                 = "${var.prefix}-SUBNET-MGMT"
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet["4"]]
}

# Route Table for Protected Subnet (unchanged)
resource "azurerm_subnet_route_table_association" "subnet3rt" {
  subnet_id      = azurerm_subnet.subnet3.id
  route_table_id = azurerm_route_table.protectedaroute.id

  lifecycle {
    ignore_changes = [route_table_id]
  }
}

resource "azurerm_route_table" "protectedaroute" {
  name                = "${var.prefix}-RT-PROTECTED-A"
  location            = var.location
  resource_group_name = azurerm_resource_group.resourcegroup.name

  route {
    name                   = "VirtualNetwork"
    address_prefix         = var.vnet
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_lb.ilb.frontend_ip_configuration[0].private_ip_address
  }
  route {
    name           = "Subnet"
    address_prefix = var.subnet["2"]
    next_hop_type  = "VnetLocal"
  }
  route {
    name                   = "Default"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_lb.ilb.frontend_ip_configuration[0].private_ip_address
  }
}