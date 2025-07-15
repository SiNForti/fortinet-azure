##############################################################################################################
#
# FortiGate Active/Active Load Balanced pair of standalone FortiGate VMs for resilience and scale
# Terraform deployment template for Microsoft Azure
#
##############################################################################################################

# Prefix for all resources created for this deployment in Microsoft Azure
variable "prefix" {
  description = "Added name to each deployed resource"
}

variable "location" {
  description = "Azure region"
}

variable "username" {}

variable "password" {}

variable "subscription_id" {}

##############################################################################################################
# FortiGate license type
##############################################################################################################

variable "FGT_COUNT" {
  description = "Number of FortiGate VMs to deploy"
  default     = 2
}

variable "FGT_IMAGE_SKU" {
  description = "Azure Marketplace default image sku hourly (PAYG 'fortinet_fg-vm_payg_2023') or byol (Bring your own license 'fortinet_fg-vm')"
  default     = "fortinet_fg-vm"
}

variable "FGT_VERSION" {
  description = "FortiGate version by default the 'latest' available version in the Azure Marketplace is selected"
  default     = "7.4.8"              # If latest word is used latest FortiOS will be deployed
}

variable "FGT_BYOL_LICENSE_FILE" {
  type        = map(string)
  description = "Map with location of license files"

  default = {
    "0" = ""      # FortiGate 1
    "1" = ""      # FortiGate 2
  }
}

variable "FGT_BYOL_FORTIFLEX_LICENSE_TOKEN" {
  type        = map(string)
  description = "Map with license tokens"

  default = {
    "0" = ""      # FortiGate 1
    "1" = ""      # FortiGate 2
  }
}

variable "FGT_SSH_PUBLIC_KEY_FILE" {
  default = ""
}

##############################################################################################################
# Accelerated Networking
# Only supported on specific VM series and CPU count: D/DSv2, D/DSv3, E/ESv3, F/FS, FSv2, and Ms/Mms
# https://azure.microsoft.com/en-us/blog/maximize-your-vm-s-performance-with-accelerated-networking-now-generally-available-for-both-windows-and-linux/
##############################################################################################################
variable "FGT_ACCELERATED_NETWORKING" {
  description = "Enables Accelerated Networking for the network interfaces of the FortiGate"
  default     = "true"
}

##############################################################################################################
# Deployment in Microsoft Azure
##############################################################################################################

terraform {
  required_version = ">= 0.12"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=2.0.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

##############################################################################################################
# Static variables
##############################################################################################################

variable "vnet" {
  description = "Virtual network address space"
  default     = "172.16.136.0/22"
}

variable "subnet" {
  type        = map(string)
  description = "Subnet address prefixes"

  default = {
    "0" = "172.16.136.0/26"   # External (now used by external-ilb)
    "1" = "172.16.136.64/26"  # Internal (used by original ilb)
    "2" = "172.16.137.0/24"   # Protected A
    "3" = "172.16.136.128/26"   # NEW: FGSP subnet
    "4" = "172.16.136.192/26"   # NEW: Management subnet
  }
}

variable "subnetmask" {
  type        = map(string)
  description = "Subnet masks"

  default = {
    "0" = "26"  # External
    "1" = "26"  # Internal
    "2" = "24"  # Protected A
    "3" = "24"  # NEW: FGSP subnet
    "4" = "24"  # NEW: Management subnet
  }
}

variable "fgt_vmsize" {
  description = "FortiGate VM size"
  default     = "Standard_F4s"
}

variable "fortinet_tags" {
  type = map(string)
  default = {
    publisher : "Fortinet",
    template : "Active-Active-ELB-ILB",
    provider : "7EB3B02F-50E5-4A3E-8CB8-2E129258AA"
  }
}

##############################################################################################################
# Resource Group
##############################################################################################################

resource "azurerm_resource_group" "resourcegroup" {
  name     = "${var.prefix}-rg"
  location = var.location
}