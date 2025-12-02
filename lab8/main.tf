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
  description = "Пароль адміністратора"
  sensitive   = true
}

resource "azurerm_resource_group" "rg8" {
  name     = "az104-rg8"
  location = "Poland Central"
}

resource "azurerm_virtual_network" "vmss_vnet" {
  name                = "vmss-vnet"
  resource_group_name = azurerm_resource_group.rg8.name
  location            = azurerm_resource_group.rg8.location
  address_space       = ["10.82.0.0/20"]
}

resource "azurerm_subnet" "vmss_subnet" {
  name                 = "subnet0"
  resource_group_name  = azurerm_resource_group.rg8.name
  virtual_network_name = azurerm_virtual_network.vmss_vnet.name
  address_prefixes     = ["10.82.0.0/24"]
}

resource "azurerm_public_ip" "vmss_lb_pip" {
  name                = "vmss-lb-pip"
  resource_group_name = azurerm_resource_group.rg8.name
  location            = azurerm_resource_group.rg8.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "vmss_lb" {
  name                = "vmss-lb"
  resource_group_name = azurerm_resource_group.rg8.name
  location            = azurerm_resource_group.rg8.location
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "LoadBalancerFrontEnd"
    public_ip_address_id = azurerm_public_ip.vmss_lb_pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "vmss_bepool" {
  loadbalancer_id = azurerm_lb.vmss_lb.id
  name            = "vmss-bepool"
}

resource "azurerm_network_security_group" "vmss_nsg" {
  name                = "vmss1-nsg"
  resource_group_name = azurerm_resource_group.rg8.name
  location            = azurerm_resource_group.rg8.location

  security_rule {
    name                       = "allow-http"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_windows_virtual_machine_scale_set" "vmss" {
  name                = "vmss1"
  resource_group_name = azurerm_resource_group.rg8.name
  location            = azurerm_resource_group.rg8.location
  
  sku                 = "Standard_B1s"
  instances           = 2              
  
  admin_password      = var.admin_password
  admin_username      = "localadmin"
  
  zones               = ["1", "2", "3"] 

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "vmss-nic"
    primary = true

    network_security_group_id = azurerm_network_security_group.vmss_nsg.id

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.vmss_subnet.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.vmss_bepool.id]
    }
  }
}

# Task 4

resource "azurerm_monitor_autoscale_setting" "vmss_autoscale" {
  name                = "autoscale-config"
  resource_group_name = azurerm_resource_group.rg8.name
  location            = azurerm_resource_group.rg8.location
  
  target_resource_id  = azurerm_windows_virtual_machine_scale_set.vmss.id

  profile {
    name = "AutoScale"

    capacity {
      default = 2
      minimum = 2
      maximum = 10
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_windows_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M" 
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_windows_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
}