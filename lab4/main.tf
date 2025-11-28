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

# Task 1

resource "azurerm_resource_group" "rg4" {
  name     = "az104-rg4"
  location = "Poland Central" 
}

resource "azurerm_virtual_network" "vnet_core" {
  name                = "CoreServicesVnet"
  resource_group_name = azurerm_resource_group.rg4.name
  location            = azurerm_resource_group.rg4.location
  
  address_space       = ["10.20.0.0/16"]
}


resource "azurerm_subnet" "subnet_shared" {
  name                 = "SharedServicesSubnet"
  resource_group_name  = azurerm_resource_group.rg4.name
  virtual_network_name = azurerm_virtual_network.vnet_core.name
  
  address_prefixes     = ["10.20.10.0/24"]
}

resource "azurerm_subnet" "subnet_db" {
  name                 = "DatabaseSubnet"
  resource_group_name  = azurerm_resource_group.rg4.name
  virtual_network_name = azurerm_virtual_network.vnet_core.name
  
  address_prefixes     = ["10.20.20.0/24"]
}

# Task 2

resource "azurerm_virtual_network" "vnet_mfg" {
  name                = "ManufacturingVnet"
  resource_group_name = azurerm_resource_group.rg4.name
  location            = azurerm_resource_group.rg4.location
  
  address_space       = ["10.30.0.0/16"]
}

resource "azurerm_subnet" "subnet_sensor1" {
  name                 = "SensorSubnet1"
  resource_group_name  = azurerm_resource_group.rg4.name
  virtual_network_name = azurerm_virtual_network.vnet_mfg.name
  
  address_prefixes     = ["10.30.20.0/24"]
}

resource "azurerm_subnet" "subnet_sensor2" {
  name                 = "SensorSubnet2"
  resource_group_name  = azurerm_resource_group.rg4.name
  virtual_network_name = azurerm_virtual_network.vnet_mfg.name
  
  address_prefixes     = ["10.30.21.0/24"]
}

# Task 3

resource "azurerm_application_security_group" "asg_web" {
  name                = "asg-web"
  location            = azurerm_resource_group.rg4.location
  resource_group_name = azurerm_resource_group.rg4.name
}

resource "azurerm_network_security_group" "nsg_secure" {
  name                = "myNSGSecure"
  location            = azurerm_resource_group.rg4.location
  resource_group_name = azurerm_resource_group.rg4.name

  # Inbound Rule: Allow traffic from ASG on ports 80, 443
  security_rule {
    name                         = "AllowASG"
    priority                     = 100
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_ranges      = ["80", "443"]
    source_address_prefix        = null
    destination_address_prefix   = "*"
    
    source_application_security_group_ids = [azurerm_application_security_group.asg_web.id]
  }

  # Outbound Rule: Deny Internet Access
  security_rule {
    name                       = "DenyInternetOutbound"
    priority                   = 4096
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*" # Any protocol
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet" # Service Tag
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_assoc_shared" {
  subnet_id                 = azurerm_subnet.subnet_shared.id
  network_security_group_id = azurerm_network_security_group.nsg_secure.id
}

# Task 4

locals {
  location = azurerm_resource_group.rg4.location
}

resource "azurerm_dns_zone" "public_zone" {
  name                = "zubiak-lab-xyz.com"
  resource_group_name = azurerm_resource_group.rg4.name
}

resource "azurerm_dns_a_record" "public_a_record" {
  name                = "www"
  zone_name           = azurerm_dns_zone.public_zone.name
  resource_group_name = azurerm_resource_group.rg4.name
  ttl                 = 3600
  records             = ["10.1.1.4"]
}

resource "azurerm_private_dns_zone" "private_zone" {
  name                = "private.zubiak-lab-xyz.com"
  resource_group_name = azurerm_resource_group.rg4.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "mfg_link" {
  name                  = "manufacturing-link"
  resource_group_name   = azurerm_resource_group.rg4.name
  private_dns_zone_name = azurerm_private_dns_zone.private_zone.name
  
  virtual_network_id    = azurerm_virtual_network.vnet_mfg.id
  
  registration_enabled = false
}

resource "azurerm_private_dns_a_record" "private_a_record" {
  name                = "sensorvm"
  zone_name           = azurerm_private_dns_zone.private_zone.name
  resource_group_name = azurerm_resource_group.rg4.name
  ttl                 = 3600
  records             = ["10.1.1.4"]
}