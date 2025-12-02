terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
}

variable "admin_password" {
  description = "Enter administration password"
  sensitive   = true
}

variable "location" {
  default = "Poland Central"
}

resource "azurerm_resource_group" "rg8" {
  name     = "az104-rg8"
  location = var.location
}

resource "azurerm_virtual_network" "vnet8" {
  name                = "az104-vnet8"
  resource_group_name = azurerm_resource_group.rg8.name
  location            = azurerm_resource_group.rg8.location
  address_space       = ["10.80.0.0/16"]
}

resource "azurerm_subnet" "subnet8" {
  name                 = "subnet8"
  resource_group_name  = azurerm_resource_group.rg8.name
  virtual_network_name = azurerm_virtual_network.vnet8.name
  address_prefixes     = ["10.80.1.0/24"]
}

resource "azurerm_public_ip" "pips" {
  count               = 2
  name                = "az104-vm${count.index + 1}-pip"
  resource_group_name = azurerm_resource_group.rg8.name
  location            = azurerm_resource_group.rg8.location
  
  allocation_method   = "Static"
  sku                 = "Standard" 
  zones               = [tostring(count.index + 1)]
}

resource "azurerm_network_interface" "nics" {
  count               = 2
  name                = "az104-vm${count.index + 1}-nic"
  location            = azurerm_resource_group.rg8.location
  resource_group_name = azurerm_resource_group.rg8.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet8.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pips[count.index].id
  }
}

resource "azurerm_windows_virtual_machine" "vms" {
  count               = 2
  name                = "az104-vm${count.index + 1}"
  resource_group_name = azurerm_resource_group.rg8.name
  location            = azurerm_resource_group.rg8.location
  zone                = tostring(count.index + 1) 
  
  size                = "Standard_B2ms"
  admin_username      = "localadmin"
  admin_password      = var.admin_password
  
  network_interface_ids = [
    azurerm_network_interface.nics[count.index].id,
  ]

  os_disk {
    name                 = "az104-vm${count.index + 1}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

# Task 2

resource "azurerm_managed_disk" "vm1_disk1" {
  name                 = "vm1-disk1"
  location             = azurerm_resource_group.rg8.location
  resource_group_name  = azurerm_resource_group.rg8.name
  storage_account_type = "StandardSSD_LRS" 
  zone                 = "1"
  create_option        = "Empty"
  disk_size_gb         = 32
}

resource "azurerm_virtual_machine_data_disk_attachment" "vm1_disk_attach" {
  managed_disk_id    = azurerm_managed_disk.vm1_disk1.id
  virtual_machine_id = azurerm_windows_virtual_machine.vms[0].id 
  lun                = 0
  caching            = "ReadWrite"
}