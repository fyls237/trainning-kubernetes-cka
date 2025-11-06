# Copy this file to terraform.tfvars and update with your values
# cp terraform.tfvars.example terraform.tfvars

# Resource Group and Location
resource_group_name = "k8s-cluster-rg"
location            = "westeurope"  # Change to your preferred region: eastus, westus2, etc.

# Network Configuration
vnet_name              = "k8s-vnet"
vnet_address_space     = "10.0.0.0/16"
subnet_name            = "k8s-subnet"
subnet_address_prefix  = "10.0.1.0/24"

# VM Configuration
admin_username = "azureuser"

# IMPORTANT: Set your public IP address for SSH access to bastion
# Find your IP: curl ifconfig.me
admin_source_ip = "0.0.0.0/0"  # ⚠️ CHANGE THIS TO YOUR IP (e.g., "203.0.113.45/32")

# Path to your SSH public key
ssh_public_key_path = "~/.ssh/id_rsa.pub"

# Cluster Configuration
master_count = 1 # Number of master nodes
worker_count = 1 # Number of worker nodes

# VM Sizes
bastion_vm_size = "Standard_B1s"  # 1 vCPU, 1 GB RAM (bastion only)
master_vm_size  = "Standard_B2s"  # 2 vCPU, 4 GB RAM
worker_vm_size  = "Standard_B1ms" # 1 vCPU, 2 GB RAM
