terraform {
  backend "local" {
    path = "local.tfstate"
  }

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 3.20.0"
    }
  }
  required_version = "~> 1.3.5"
}

locals {
  name_template = "%s-%s-%s-%02d"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "east" {
  location = "eastus"
  name     = format(local.name_template, var.product, var.env, "rg", 1)
}

resource "azurerm_resource_group" "west" {
  location = "westeurope"
  name     = format(local.name_template, var.product, var.env, "rg", 2)
}

module "env" {
  source = "./modules/env"

  resource_group_name = azurerm_resource_group.west.name
  vm_password         = "CustomHardPass#$23"
  name_template       = format("%s-%s-%s-%s", var.product, var.env, "%s", "%02d")
  depends_on          = [
    azurerm_resource_group.west
  ]
}
module "env2" {
  source = "./modules/env"

  resource_group_name = azurerm_resource_group.east.name
  vm_password         = "CustomHardPass#$23"
  name_template       = format("%s-%s-%s-%s", var.product, var.env, "%s", "%02d")
  depends_on          = [
    azurerm_resource_group.east
  ]
}

resource "azurerm_resource_group" "this" {
  location = "westeurope"
  name     = format(local.name_template, "shared", var.env, "rg", 1)
}

resource "azurerm_traffic_manager_profile" "this" {
  name                   = format(local.name_template, "shared", var.env, "tm", 1)
  resource_group_name    = azurerm_resource_group.this.name
  traffic_routing_method = "Weighted"

  dns_config {
    relative_name = "profile"
    ttl           = 60
  }

  monitor_config {
    protocol                     = "HTTP"
    port                         = 80
    path                         = "/"
    interval_in_seconds          = 30
    timeout_in_seconds           = 9
    tolerated_number_of_failures = 3
  }
}

data "azurerm_public_ip" "one" {
  name                = module.env.public_ip.name
  resource_group_name = module.env.public_ip.resource_group
  depends_on          = [
    module.env
  ]
}

resource "azurerm_traffic_manager_azure_endpoint" "main" {
  name               = "example-endpoint"
  profile_id         = azurerm_traffic_manager_profile.this.id
  weight             = 100
  target_resource_id = data.azurerm_public_ip.one.id
}

data "azurerm_public_ip" "two" {
  name                = module.env2.public_ip.name
  resource_group_name = module.env2.public_ip.resource_group
  depends_on          = [
    module.env2
  ]
}

resource "azurerm_traffic_manager_azure_endpoint" "main2" {
  name               = "example-endpoint2"
  profile_id         = azurerm_traffic_manager_profile.this.id
  weight             = 100
  target_resource_id = data.azurerm_public_ip.two.id
}