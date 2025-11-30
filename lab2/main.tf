terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.100.0"
    }
  }
}

provider "azurerm" {

skip_provider_registration = true

  features {}
}

# Task 1

resource "azurerm_management_group" "mg1" {
  name         = "az104-mg1"
  display_name = "az104-mg1"
}

# Task 2


variable "helpdesk_group_object_id" {
  description = "0c0c3798-bce5-4732-9ec6-704d76ebc436"
  type        = string
}

resource "azurerm_role_assignment" "vm_contributor_assignment" {
  scope                = azurerm_management_group.mg1.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = var.helpdesk_group_object_id
}

# Task 3


data "azurerm_role_definition" "support_request_contributor" {
  name = "Support Request Contributor"
}

resource "azurerm_role_definition" "custom_support_role" {
  name        = "Custom Support Request"
  description = "A custom contributor role for support requests."


  scope       = azurerm_management_group.mg1.id

  assignable_scopes = [
    azurerm_management_group.mg1.id,
  ]

  permissions {
    actions = data.azurerm_role_definition.support_request_contributor.permissions[0].actions

    data_actions = data.azurerm_role_definition.support_request_contributor.permissions[0].data_actions

    not_actions = distinct(concat(
      data.azurerm_role_definition.support_request_contributor.permissions[0].not_actions,
      ["Microsoft.Support/register/action"]
    ))

    not_data_actions = data.azurerm_role_definition.support_request_contributor.permissions[0].not_data_actions
  }
}

resource "azurerm_resource_group" "rg2" {
  name     = "az104-rg2"
  location = "East US"
  tags = {
    "Cost Center" = "000"
  }
}

data "azurerm_policy_definition" "require_tag" {
  display_name = "Require a tag and its value on resources"
}

resource "azurerm_policy_assignment" "require_tag_assignment" {
  name                 = "Require Cost Center tag"
  scope                = azurerm_resource_group.rg2.id
  policy_definition_id = data.azurerm_policy_definition.require_tag.id
  display_name         = "Require Cost Center tag and its value on resources"
  description          = "Require Cost Center tag and its value on all resources in the resource group"
  enforce              = true

  parameters = jsonencode({
    "tagName" = {
      "value" = "Cost Center"
    },
    "tagValue" = {
      "value" = "000"
    }
  })
}

data "azurerm_policy_definition" "inherit_tag" {
  display_name = "Inherit a tag from the resource group if missing"
}

resource "azurerm_policy_assignment" "inherit_tag_assignment" {
  name                 = "Inherit the Cost Center tag"
  scope                = azurerm_resource_group.rg2.id
  policy_definition_id = data.azurerm_policy_definition.inherit_tag.id
  display_name         = "Inherit the Cost Center tag and its value 000 from the resource group"
  description          = "Inherit the Cost Center tag and its value 000 from the resource group if missing"
  enforce              = true

  parameters = jsonencode({
    "tagName" = {
      "value" = "Cost Center"
    }
  })

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_policy_remediation" "inherit_tag_remediation" {
  name                 = "remediate-cost-center-tag"
  scope                = azurerm_policy_assignment.inherit_tag_assignment.scope
  policy_assignment_id = azurerm_policy_assignment.inherit_tag_assignment.id
  
  policy_definition_reference_id = data.azurerm_policy_definition.inherit_tag.name
}

resource "azurerm_management_lock" "rg2_lock" {
  name       = "rg-lock"
  scope      = azurerm_resource_group.rg2.id
  lock_level = "CanNotDelete"
  notes      = "Lock to prevent accidental deletion"
}
