# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Subnet for Kubernetes nodes
resource "azurerm_subnet" "k8s_subnet" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_address_prefix]
<<<<<<< HEAD
=======

  service_endpoints = [ "Microsoft.Storage" ]
>>>>>>> feat/azurefile
}

# Network Security Group for Bastion
resource "azurerm_network_security_group" "bastion_nsg" {
  name                = "k8s-bastion-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # SSH from your IP only
  security_rule {
    name                       = "SSH-In"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_source_ip
    destination_address_prefix = "*"
  }

  # Allow outbound SSH to internal nodes
  security_rule {
    name                       = "SSH-Out"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = var.subnet_address_prefix
  }
}

# Network Security Group for Master Nodes
resource "azurerm_network_security_group" "master_nsg" {
  name                = "k8s-master-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # SSH from bastion only
  security_rule {
    name                       = "SSH-Bastion"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.subnet_address_prefix
    destination_address_prefix = "*"
  }

  # Kubernetes API Server
  security_rule {
    name                       = "K8s-API"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = var.subnet_address_prefix
    destination_address_prefix = "*"
  }

  # etcd server client API
  security_rule {
    name                       = "etcd"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "2379-2380"
    source_address_prefix      = var.subnet_address_prefix
    destination_address_prefix = "*"
  }

  # Kubelet API, kube-scheduler, kube-controller-manager
  security_rule {
    name                       = "K8s-Master-Services"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "10250-10252"
    source_address_prefix      = var.subnet_address_prefix
    destination_address_prefix = "*"
  }

  # Allow all internal traffic
  security_rule {
    name                       = "Internal-Traffic"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.subnet_address_prefix
    destination_address_prefix = "*"
  }
}

# Network Security Group for Worker Nodes
resource "azurerm_network_security_group" "worker_nsg" {
  name                = "k8s-worker-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # SSH from bastion only
  security_rule {
    name                       = "SSH-Bastion"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.subnet_address_prefix
    destination_address_prefix = "*"
  }

  # Kubelet API
  security_rule {
    name                       = "Kubelet"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "10250"
    source_address_prefix      = var.subnet_address_prefix
    destination_address_prefix = "*"
  }

  # NodePort Services
  security_rule {
    name                       = "NodePort"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "30000-32767"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow all internal traffic
  security_rule {
    name                       = "Internal-Traffic"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.subnet_address_prefix
    destination_address_prefix = "*"
  }
}
