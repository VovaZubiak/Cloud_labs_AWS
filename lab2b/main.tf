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

resource "azurerm_resource_group" "rg2" {
  name     = "az104-rg2"
  location = "Poland Central"
  tags = {
    "Cost Center" = "000"
  }
}

# Task 3

data "azurerm_policy_definition" "inherit_tag" {
  display_name = "Inherit a tag from the resource group if missing"
}

resource "azurerm_resource_group_policy_assignment" "assign_inherit_tag" {
  name                 = "inherit-cost-center-tag"
  resource_group_id    = azurerm_resource_group.rg2.id
  policy_definition_id = data.azurerm_policy_definition.inherit_tag.id

  display_name = "Inherit the Cost Center tag and its value 000"
  description  = "Inherit the Cost Center tag from the resource group if missing"
  location     = azurerm_resource_group.rg2.location

  parameters = jsonencode({
    "tagName" = {
      "value" = "Cost Center"
    }
  })

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "policy_role" {
  scope                = azurerm_resource_group.rg2.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_resource_group_policy_assignment.assign_inherit_tag.identity[0].principal_id
}

resource "azurerm_resource_group_policy_remediation" "remediate_tags" {
  name                 = "remediate-tags-task"
  resource_group_id    = azurerm_resource_group.rg2.id
  policy_assignment_id = azurerm_resource_group_policy_assignment.assign_inherit_tag.id
  resource_discovery_mode = "ReEvaluateCompliance"
}
data "azurerm_client_config" "current" {}

# Task 4

resource "azurerm_management_lock" "rg_lock" {
  name       = "rg-lock"
  scope      = azurerm_resource_group.rg2.id
  lock_level = "CanNotDelete"
  notes      = "Lock to prevent accidental deletion of Lab 02b resources"
}