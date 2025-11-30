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

variable "admin_username" {
  default     = "localadmin"
}

variable "admin_password" { 
  description = "Secure password for VM admin access"
  sensitive   = true 
}
locals {
  resource_location = "Poland Central"

  vm_data = {
    "vm0" = { subnet_prefix = "10.60.0.0/24", script_logic = "" },
    "vm1" = { subnet_prefix = "10.60.1.0/24", script_logic = " && powershell.exe New-Item -Path 'c:\\inetpub\\wwwroot' -Name 'image' -Itemtype 'Directory' && powershell.exe New-Item -Path 'c:\\inetpub\\wwwroot\\image\\' -Name 'iisstart.htm' -ItemType 'file' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\image\\iisstart.htm' -Value $('Image from: ' + $env:computername)" }, 
    "vm2" = { subnet_prefix = "10.60.2.0/24", script_logic = " && powershell.exe New-Item -Path 'c:\\inetpub\\wwwroot' -Name 'video' -Itemtype 'Directory' && powershell.exe New-Item -Path 'c:\\inetpub\\wwwroot\\video\\' -Name 'iisstart.htm' -ItemType 'file' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\video\\iisstart.htm' -Value $('Video from: ' + $env:computername)" }  
  }
  
  base_script = "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
}

resource "azurerm_resource_group" "rg6" {
  name     = "az104-rg6"
  location = local.resource_location
}

resource "azurerm_network_security_group" "nsg1" {
  name                = "az104-06-nsg1"
  location            = azurerm_resource_group.rg6.location
  resource_group_name = azurerm_resource_group.rg6.name

  security_rule {
    name                       = "default-allow-rdp"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  security_rule {
    name                       = "default-allow-http"
    priority                   = 1100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_virtual_network" "vnet1" {
  name                = "az104-06-vnet1"
  resource_group_name = azurerm_resource_group.rg6.name
  location            = azurerm_resource_group.rg6.location
  address_space       = ["10.60.0.0/22"] 
}

resource "azurerm_subnet" "subnets" {
  for_each             = local.vm_data
  name                 = "subnet${each.key}"
  resource_group_name  = azurerm_resource_group.rg6.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = [each.value.subnet_prefix]
}

resource "azurerm_subnet_network_security_group_association" "nsg_associations" {
  for_each                  = azurerm_subnet.subnets
  subnet_id                 = each.value.id
  network_security_group_id = azurerm_network_security_group.nsg1.id
}

resource "azurerm_network_interface" "nics" {
  for_each            = local.vm_data
  name                = "az104-06-nic${each.key}"
  location            = azurerm_resource_group.rg6.location
  resource_group_name = azurerm_resource_group.rg6.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnets[each.key].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = (each.key == "vm2" ? azurerm_public_ip.vm2_public_ip.id : null)
  }
}

resource "azurerm_virtual_machine" "vms" {
  for_each              = local.vm_data
  name                  = "az104-06-vm${each.key}"
  location              = azurerm_resource_group.rg6.location
  resource_group_name   = azurerm_resource_group.rg6.name
  network_interface_ids = [azurerm_network_interface.nics[each.key].id]
  vm_size               = "Standard_B1s"
  
  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "az104-06-vm${each.key}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "az104-06-vm${each.key}"
    admin_username = var.admin_username
    admin_password = var.admin_password
  }
  
  os_profile_windows_config {
    provision_vm_agent = true
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_virtual_machine_extension" "iis_setup" {
  for_each             = local.vm_data
  name                 = "customScriptExtension-${each.key}"
  virtual_machine_id   = azurerm_virtual_machine.vms[each.key].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.7"

  settings = jsonencode({
    commandToExecute = "${local.base_script}${each.value.script_logic}"
  })
  
  depends_on = [
    azurerm_virtual_machine.vms
  ]
}

resource "azurerm_public_ip" "vm2_public_ip" {
  name                = "vm2-web-pip"
  resource_group_name = azurerm_resource_group.rg6.name
  location            = azurerm_resource_group.rg6.location
  
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Task 2


resource "azurerm_public_ip" "lb_pip" {
  name                = "az104-lbpip"
  resource_group_name = azurerm_resource_group.rg6.name
  location            = azurerm_resource_group.rg6.location
  
  sku                 = "Standard" 
  allocation_method   = "Static"
}

resource "azurerm_lb" "lb" {
  name                = "az104-lb"
  resource_group_name = azurerm_resource_group.rg6.name
  location            = azurerm_resource_group.rg6.location
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "az104-fe"
    public_ip_address_id = azurerm_public_ip.lb_pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "be_pool" {
  name                = "az104-be"
  loadbalancer_id     = azurerm_lb.lb.id
}

resource "azurerm_lb_probe" "hp" {
  name                = "az104-hp"
  loadbalancer_id     = azurerm_lb.lb.id
  protocol            = "Tcp"
  port                = 80
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "lb_rule" {
  name                           = "az104-lbrule"
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "az104-fe"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.be_pool.id]
  probe_id                       = azurerm_lb_probe.hp.id
}

resource "azurerm_network_interface_backend_address_pool_association" "nic0_pool_assoc" {
  network_interface_id    = azurerm_network_interface.nics["vm0"].id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.be_pool.id
}

resource "azurerm_network_interface_backend_address_pool_association" "nic1_pool_assoc" {
  network_interface_id    = azurerm_network_interface.nics["vm1"].id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.be_pool.id
}

# task 3

resource "azurerm_subnet" "appgw_subnet" {
  name                 = "subnet-appgw"
  resource_group_name  = azurerm_resource_group.rg6.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.60.3.224/27"] 
}

resource "azurerm_public_ip" "appgw_pip" {
  name                = "az104-gwpip"
  resource_group_name = azurerm_resource_group.rg6.name
  location            = azurerm_resource_group.rg6.location
  sku                 = "Standard" 
  allocation_method   = "Static"
}

resource "azurerm_application_gateway" "appgw" {
  name                = "az104-appgw"
  resource_group_name = azurerm_resource_group.rg6.name
  location            = azurerm_resource_group.rg6.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "appGatewayIpConfig"
    subnet_id = azurerm_subnet.appgw_subnet.id
  }

  frontend_ip_configuration {
    name                 = "az104-listener"
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }
  
  frontend_port {
    name = "port_80"
    port = 80
  }

  backend_address_pool {
    name  = "az104-appgwbe" 
    ip_addresses = [
        azurerm_network_interface.nics["vm1"].private_ip_address,
        azurerm_network_interface.nics["vm2"].private_ip_address
    ]
  }

  backend_address_pool {
    name  = "az104-imagebe" 
    ip_addresses = [azurerm_network_interface.nics["vm1"].private_ip_address]
  }

  backend_address_pool {
    name  = "az104-videobe" 
    ip_addresses = [azurerm_network_interface.nics["vm2"].private_ip_address]
  }
  
  backend_http_settings {
    name                  = "az104-http"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 4
    cookie_based_affinity = "Disabled"
    probe_name            = "appGwProbe"
  }
  
  probe {
    name                = "appGwProbe"
    protocol            = "Http"
    host                = "127.0.0.1"
    path                = "/"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
  }

  http_listener {
    name                           = "az104-listener"
    frontend_ip_configuration_name = "az104-listener"
    frontend_port_name             = "port_80"
    protocol                       = "Http"
  }

  url_path_map {
    name = "pathMap"
    default_backend_address_pool_name = "az104-appgwbe" 
    default_backend_http_settings_name = "az104-http"

    path_rule {
      name                       = "images"
      paths                      = ["/image/*"]
      backend_address_pool_name  = "az104-imagebe"
      backend_http_settings_name = "az104-http"
    }

    path_rule {
      name                       = "videos"
      paths                      = ["/video/*"]
      backend_address_pool_name  = "az104-videobe"
      backend_http_settings_name = "az104-http"
    }
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20170401S" 
  }
  
  request_routing_rule {
    name                       = "az104-gwrule"
    rule_type                  = "PathBasedRouting"
    http_listener_name         = "az104-listener"
    priority                   = 10
    url_path_map_name          = "pathMap"
  }
}