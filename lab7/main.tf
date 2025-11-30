# task 1
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
}


variable "client_public_ip_address" {
  description = "Enter public ip"
  type        = string
}

resource "azurerm_resource_group" "rg7" {
  name     = "az104-rg7"
  location = "Poland Central" 
}

resource "random_string" "storage_name_suffix" {
  length  = 12
  special = false
  upper   = false
  numeric = true
}

resource "azurerm_storage_account" "sa7" {
  name                     = "az104s${random_string.storage_name_suffix.result}" 
  resource_group_name      = azurerm_resource_group.rg7.name
  location                 = azurerm_resource_group.rg7.location
  
  account_tier             = "Standard"
  account_replication_type = "LRS" 
  min_tls_version          = "TLS1_2"
}

resource "azurerm_storage_account_network_rules" "sa7_network" {
  storage_account_id           = azurerm_storage_account.sa7.id
  
  default_action               = "Deny" 
  ip_rules                     = [] 
  virtual_network_subnet_ids = [azurerm_subnet.default_subnet.id]
  bypass                       = ["AzureServices"] 
}

resource "azurerm_storage_management_policy" "sa7_policy" {
  storage_account_id           = azurerm_storage_account.sa7.id
  
  rule {
    name    = "Movetocool"
    enabled = true
    
    filters {
      blob_types   = ["blockBlob"]
    }
    
    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than = 30 
      }
    }
  }
}

# Task 2

resource "azurerm_storage_container" "data_container" {
  name                  = "data"
  storage_account_name  = azurerm_storage_account.sa7.name
  container_access_type = "private" 
}

resource "azurerm_storage_container_immutability_policy" "retention_policy" {
  storage_container_resource_manager_id = azurerm_storage_container.data_container.resource_manager_id
  immutability_period_in_days = 180
}
resource "azurerm_storage_blob" "test_image" {
  name                   = "securitytest/sample.txt" 
  storage_account_name   = azurerm_storage_account.sa7.name
  storage_container_name = azurerm_storage_container.data_container.name
  type                     = "Block"
  access_tier              = "Hot"
  source_content           = base64encode("This is the lab 07 test content.") 
  content_type             = "text/plain"
}

# Task 3

resource "azurerm_virtual_network" "vnet1" {
  name                = "vnet1"
  resource_group_name = azurerm_resource_group.rg7.name
  location            = azurerm_resource_group.rg7.location
  address_space       = ["10.0.0.0/16"] 
}

resource "azurerm_subnet" "default_subnet" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.rg7.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.0.0.0/24"]
  service_endpoints    = ["Microsoft.Storage"] 
}

resource "azurerm_storage_share" "share1" {
  name                 = "share1"
  storage_account_name = azurerm_storage_account.sa7.name
  quota                = 100
}