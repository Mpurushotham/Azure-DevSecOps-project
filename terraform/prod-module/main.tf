terraform {
  required_version = ">= 1.3"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.0"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

locals {
  prefix = "${var.prefix}-${random_string.suffix.result}"
}

resource "azurerm_resource_group" "rg" {
  name     = "${local.prefix}-rg"
  location = var.location
}

# VNet with two subnets (control plane private endpoints + nodepool)
resource "azurerm_virtual_network" "vnet" {
  name                = "${local.prefix}-vnet"
  address_space       = ["10.100.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "${local.prefix}-aks-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.100.1.0/24"]
  delegation {
    name = "aks_delegation"
    service_delegation {
      name = "Microsoft.ContainerService/managedClusters"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join"]
    }
  }
}

resource "azurerm_subnet" "acr_subnet" {
  name                 = "${local.prefix}-acr-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.100.2.0/24"]
}

# Private Container Registry with Network Rule Set example
resource "azurerm_container_registry" "acr" {
  name                = lower(replace("${local.prefix}acr", "/[^a-z0-9]/", ""))
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku                 = "Premium"
  admin_enabled       = false
}

# Log Analytics workspace (for AKS monitoring)
resource "azurerm_log_analytics_workspace" "law" {
  name                = "${local.prefix}-law"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
}

# Key Vault
resource "azurerm_key_vault" "kv" {
  name                        = "${local.prefix}-kv"
  location                    = var.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = var.tenant_id
  sku_name                    = "standard"
  soft_delete_enabled         = true
  purge_protection_enabled    = false
  access_policy {
    tenant_id = var.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    key_permissions = ["get","list"]
    secret_permissions = ["get","list"]
  }
}

data "azurerm_client_config" "current" {}

# AKS (private cluster skeleton)
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${local.prefix}-aks"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "${local.prefix}-aks"

  default_node_pool {
    name       = "nodepool"
    node_count = 3
    vm_size    = "Standard_DS3_v2"
    vnet_subnet_id = azurerm_subnet.aks_subnet.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "calico"
    service_cidr      = "10.96.0.0/12"
    dns_service_ip    = "10.96.0.10"
    docker_bridge_cidr = "172.17.0.1/16"
  }

  api_server_access_profile {
    enable_private_cluster = true
  }

  addon_profile {
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
    }
  }

  role_based_access_control {
    enabled = true
    azure_active_directory {
      managed = true
      # If you want to configure AAD admin group/object IDs add them via "admin_group_object_ids"
      admin_group_object_ids = var.aks_admins
    }
  }

  depends_on = [azurerm_subnet.aks_subnet]
}

# Assign AcrPull to AKS managed identity (so pods can pull from private ACR)
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}
output "aks_name" {
  value = azurerm_kubernetes_cluster.aks.name
}
output "resource_group" {
  value = azurerm_resource_group.rg.name
}
