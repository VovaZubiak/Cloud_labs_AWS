terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  skip_provider_registration = true
}

# Task 1

variable "admin_username" {
  default     = "localadmin"
  description = "Username for the Virtual Machines"
}

variable "admin_password" { 
  description = "Complex password for the Virtual Machines"
  sensitive   = true 
}

resource "azurerm_resource_group" "rg5" {
  name     = "az104-rg5"
  location = "Poland Central" 
}

# Task 2

resource "azurerm_virtual_network" "vnet_core" {
  name                = "CoreServicesVnet"
  resource_group_name = azurerm_resource_group.rg5.name
  location            = azurerm_resource_group.rg5.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet_core" {
  name                 = "CoreSubnet"
  resource_group_name  = azurerm_resource_group.rg5.name
  virtual_network_name = azurerm_virtual_network.vnet_core.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_network_interface" "nic_core" {
  name                = "CoreServicesVM-nic"
  location            = azurerm_resource_group.rg5.location
  resource_group_name = azurerm_resource_group.rg5.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet_core.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "vm_core" {
  name                = "CoreServicesVM"
  location            = azurerm_resource_group.rg5.location
  resource_group_name = azurerm_resource_group.rg5.name
  network_interface_ids = [azurerm_network_interface.nic_core.id]
  vm_size               = "Standard_B1s"
  
  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "coreservicesvm-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "CoreServicesVM"
    admin_username = var.admin_username
    admin_password = var.admin_password
  }
  
  os_profile_windows_config {}
}

resource "azurerm_virtual_network" "vnet_mfg" {
  name                = "ManufacturingVnet"
  resource_group_name = azurerm_resource_group.rg5.name
  location            = azurerm_resource_group.rg5.location
  address_space       = ["172.16.0.0/16"]
}

resource "azurerm_subnet" "subnet_mfg" {
  name                 = "ManufacturingSubnet"
  resource_group_name  = azurerm_resource_group.rg5.name
  virtual_network_name = azurerm_virtual_network.vnet_mfg.name
  address_prefixes     = ["172.16.0.0/24"]
}

resource "azurerm_network_interface" "nic_mfg" {
  name                = "ManufacturingVM-nic"
  location            = azurerm_resource_group.rg5.location
  resource_group_name = azurerm_resource_group.rg5.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet_mfg.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "vm_mfg" {
  name                = "ManufacturingVM"
  location            = azurerm_resource_group.rg5.location
  resource_group_name = azurerm_resource_group.rg5.name
  network_interface_ids = [azurerm_network_interface.nic_mfg.id]
  vm_size               = "Standard_B1s"
  
  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "manufacturingvm-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "ManufacturingVM"
    admin_username = var.admin_username
    admin_password = var.admin_password
  }
  
  os_profile_windows_config {}
}


# Task 4

resource "azurerm_virtual_network_peering" "core_to_mfg" {
  name                      = "Core-to-Mfg"
  resource_group_name       = azurerm_resource_group.rg5.name
  virtual_network_name      = azurerm_virtual_network.vnet_core.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_mfg.id
  
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "mfg_to_core" {
  name                      = "Mfg-to-Core"
  resource_group_name       = azurerm_resource_group.rg5.name
  virtual_network_name      = azurerm_virtual_network.vnet_mfg.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_core.id
  
  allow_virtual_network_access = true
}

resource "azurerm_application_security_group" "asg_web" {
  name                = "asg-web"
  location            = azurerm_resource_group.rg5.location
  resource_group_name = azurerm_resource_group.rg5.name
}

resource "azurerm_network_security_group" "nsg_secure" {
  name                = "myNSGSecure"
  location            = azurerm_resource_group.rg5.location
  resource_group_name = azurerm_resource_group.rg5.name

  security_rule {
    name                         = "AllowASG"
    priority                     = 100
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_ranges      = ["80", "443"]
    destination_address_prefix   = "*"
    source_application_security_group_ids = [azurerm_application_security_group.asg_web.id]
  }

  security_rule {
    name                         = "AllowRDPfromMFGVNet"
    priority                     = 101
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "*"
    source_port_range            = "*"
    destination_port_range       = "3389"
    source_address_prefix        = "172.16.0.0/16"
    destination_address_prefix   = "*"
  }
  
  security_rule {
    name                       = "DenyInternetOutbound"
    priority                   = 4096
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}


resource "azurerm_subnet_network_security_group_association" "nsg_assoc_core" {
  subnet_id                 = azurerm_subnet.subnet_core.id 
  network_security_group_id = azurerm_network_security_group.nsg_secure.id
}

# Task 6

resource "azurerm_route_table" "rt_block_internet" {
  name                = "myRouteTable" 
  resource_group_name = azurerm_resource_group.rg5.name
  location            = azurerm_resource_group.rg5.location
  bgp_route_propagation_enabled = true
}

resource "azurerm_route" "route_deny" {
  name                   = "route-internet"
  resource_group_name    = azurerm_resource_group.rg5.name
  route_table_name       = azurerm_route_table.rt_block_internet.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "None"
}

resource "azurerm_subnet_route_table_association" "route_assoc_mfg" {
  subnet_id      = azurerm_subnet.subnet_mfg.id
  route_table_id = azurerm_route_table.rt_block_internet.id
}
