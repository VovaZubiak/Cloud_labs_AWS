terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
}


# Task 1

resource "azurerm_resource_group" "rg3" {
  name     = "az104-rg3"
  location = "Poland Central" 
}

resource "azurerm_managed_disk" "disk1" {
  name                 = "az104-disk1"
  location             = azurerm_resource_group.rg3.location
  resource_group_name  = azurerm_resource_group.rg3.name
  
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 32
}


# Task 2

resource "azurerm_managed_disk" "disk2" {
  name                 = "az104-disk2"
  location             = azurerm_resource_group.rg3.location
  resource_group_name  = azurerm_resource_group.rg3.name
  
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 32
}


# Task 3

resource "random_string" "storage_suffix" {
  length  = 8
  special = false
  upper   = false
  numeric = true
}

resource "azurerm_storage_account" "sa_cloudshell" {
  name                     = "stcl${random_string.storage_suffix.result}"
  resource_group_name      = azurerm_resource_group.rg3.name
  location                 = azurerm_resource_group.rg3.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "fileshare_cloudshell" {
  name                 = "fs-cloudshell"
  storage_account_name = azurerm_storage_account.sa_cloudshell.name
  quota                = 5
}

resource "azurerm_managed_disk" "disk3" {
  name                 = "az104-disk3"
  location             = azurerm_resource_group.rg3.location
  resource_group_name  = azurerm_resource_group.rg3.name
  
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 32
}

# Task 4

resource "azurerm_managed_disk" "disk4" {
  name                 = "az104-disk4"
  location             = azurerm_resource_group.rg3.location
  resource_group_name  = azurerm_resource_group.rg3.name
  
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 32
}


# Task 5

resource "azurerm_managed_disk" "disk5" {
  name                 = "az104-disk5"
  location             = azurerm_resource_group.rg3.location
  resource_group_name  = azurerm_resource_group.rg3.name
  
  storage_account_type = "StandardSSD_LRS" 
  
  create_option        = "Empty"
  disk_size_gb         = 32
}
