variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "k8s-cluster-rg"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "westeurope"
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
  default     = "k8s-vnet"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
  default     = "k8s-subnet"
}

variable "subnet_address_prefix" {
  description = "Address prefix for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureuser"
}

variable "admin_source_ip" {
  description = "Your public IP address for SSH access (format: x.x.x.x/32)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "ssh_public_key_path" {
  description = "Path to your SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "master_count" {
  description = "Number of master nodes"
  type        = number
  default     = 3
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "master_vm_size" {
  description = "VM size for master nodes (2 vCPU, 4 GB RAM minimum)"
  type        = string
  default     = "Standard_B2s"
}

variable "worker_vm_size" {
  description = "VM size for worker nodes (1 vCPU, 2 GB RAM minimum)"
  type        = string
  default     = "Standard_B1ms"
}

variable "bastion_vm_size" {
  description = "VM size for bastion host (1 vCPU, 1 GB RAM)"
  type        = string
  default     = "Standard_B1s"
}
