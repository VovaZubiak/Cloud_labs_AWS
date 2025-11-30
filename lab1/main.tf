terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azuread" {}

variable "guest_email" {
  description = "Email адреса для запрошення зовнішнього користувача"
  type        = string
}

data "azuread_domains" "default" {
  only_initial = true
}

resource "random_password" "user_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azuread_user" "user1" {
  user_principal_name = "az104-user1@${data.azuread_domains.default.domains.0.domain_name}"
  display_name        = "az104-user1"
  mail_nickname       = "az104-user1"
  
  password            = random_password.user_password.result
  force_password_change = false

  job_title           = "IT Lab Administrator"
  department          = "IT"
  usage_location      = "US"
  account_enabled     = true
}

resource "azuread_invitation" "guest_invite" {
  user_email_address = var.guest_email
  redirect_url       = "https://portal.azure.com"
  
  message {
    body = "Welcome to Azure and our group project"
  }
}

output "user1_password" {
  value     = random_password.user_password.result
  sensitive = true
}

output "user1_upn" {
  value = azuread_user.user1.user_principal_name
}

# Task 2

data "azuread_client_config" "current" {}

resource "azuread_group" "it_admins" {
  display_name     = "IT Lab Administrators"
  description      = "Administrators that manage the IT lab"
  security_enabled = true
  mail_enabled     = false
  types            = []

  owners = [data.azuread_client_config.current.object_id]

  members = [
    azuread_user.user1.object_id,           
    azuread_invitation.guest_invite.user_id
  ]
}