terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "azurerm" {
  features {
      virtual_machine {
      skip_shutdown_and_force_delete = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    }
}

# ── Resource Group ────────────────────────────────────────
resource "azurerm_resource_group" "rg" {
  name     = "rg-acclotlab-bckosf"
  location = "westus3"

  tags = {
    environment = "lab"
    project     = "acclotlab"
  }
}

# ── Virtual Network ───────────────────────────────────────
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-acclotlab"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.20.0.0/16"]

  tags = {
    environment = "lab"
    project     = "acclotlab"
  }
}

# ── Lab VM Subnet ─────────────────────────────────────────
resource "azurerm_subnet" "lab" {
  name                 = "snet-acclotlab"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.20.1.0/24"]
  default_outbound_access_enabled = false
}

# ── AzureBastionSubnet — required name, min /26 ───────────
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.20.2.0/26"]
  default_outbound_access_enabled = false
}

# ── Bastion Public IP ─────────────────────────────────────
resource "azurerm_public_ip" "bastion" {
  name                = "pip-bastion-lab"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  ip_tags = {
    "FirstPartyUsage" = "/Unprivileged"
  }

  tags = {
    environment = "lab"
    project     = "acclotlab"
  }
}

# ── Bastion Standard with Shareable Links ────────────────
resource "azurerm_bastion_host" "bastion" {
  name                   = "bastion-acclotlab"
  location               = azurerm_resource_group.rg.location
  resource_group_name    = azurerm_resource_group.rg.name
  sku                    = "Standard"
  shareable_link_enabled = true
  tunneling_enabled      = true
  

  ip_configuration {
    name                 = "ipconfig1"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  tags = {
    environment = "lab"
    project     = "acclotlab"
  }
}

# ── NSG for lab VMs ───────────────────────────────────────
resource "azurerm_network_security_group" "lab" {
  name                = "nsg-lab-vms"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-RDP-From-Bastion"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "lab"
    project     = "acclotlab"
  }
}

# ── NIC per VM (loop) ─────────────────────────────────────
resource "azurerm_network_interface" "lab" {
  count               = var.vm_count
  name                = "nic-lab-vm-${count.index + 1}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.lab.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = "lab"
    project     = "acclotlab"
  }
}

# ── NSG association ───────────────────────────────────────
resource "azurerm_network_interface_security_group_association" "lab" {
  count                     = var.vm_count
  network_interface_id      = azurerm_network_interface.lab[count.index].id
  network_security_group_id = azurerm_network_security_group.lab.id
}

# ── Lab VMs (loop) ────────────────────────────────────────
resource "azurerm_windows_virtual_machine" "lab" {
  count               = var.vm_count
  name                = "lab-vm-${count.index + 1}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D2s_v5"
  admin_username      = "accwig"
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.lab[count.index].id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-datacenter-gensecond"
    version   = "latest"
  }

  patch_mode               = "AutomaticByPlatform"
  enable_automatic_updates = true

  tags = {
    environment  = "lab"
    project      = "acclotlab"
    lab_attendee = "vm-${count.index + 1}"
  }
}


#test