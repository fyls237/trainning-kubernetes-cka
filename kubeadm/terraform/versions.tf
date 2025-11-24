terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

provider "azurerm" {
  features {}
  tenant_id = "adf55701-79bd-4548-abec-e0f364c27354"
  subscription_id = "ef90f1f8-dfd6-4cd7-81f1-bd37f18abb1e"
}
