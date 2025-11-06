# Bastion Host Public IP
output "bastion_public_ip" {
  description = "Public IP address of bastion host"
  value       = azurerm_public_ip.bastion_pip.ip_address
}

# Bastion Host Private IP
output "bastion_private_ip" {
  description = "Private IP address of bastion host"
  value       = azurerm_network_interface.bastion_nic.private_ip_address
}

# Master Nodes Private IPs
output "master_private_ips" {
  description = "Private IP addresses of master nodes"
  value = {
    for i in range(var.master_count) :
    "master-${i + 1}" => azurerm_network_interface.master_nic[i].private_ip_address
  }
}

# Worker Nodes Private IPs
output "worker_private_ips" {
  description = "Private IP addresses of worker nodes"
  value = {
    for i in range(var.worker_count) :
    "worker-${i + 1}" => azurerm_network_interface.worker_nic[i].private_ip_address
  }
}

# SSH Command to Bastion
output "ssh_bastion" {
  description = "SSH command to connect to bastion host"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.bastion_pip.ip_address}"
}

# SSH Commands for Master Nodes via Bastion
output "ssh_commands_masters" {
  description = "SSH commands to connect to master nodes via bastion (ProxyJump)"
  value = {
    for i in range(var.master_count) :
    "master-${i + 1}" => "ssh -J ${var.admin_username}@${azurerm_public_ip.bastion_pip.ip_address} ${var.admin_username}@${azurerm_network_interface.master_nic[i].private_ip_address}"
  }
}

# SSH Commands for Worker Nodes via Bastion
output "ssh_commands_workers" {
  description = "SSH commands to connect to worker nodes via bastion (ProxyJump)"
  value = {
    for i in range(var.worker_count) :
    "worker-${i + 1}" => "ssh -J ${var.admin_username}@${azurerm_public_ip.bastion_pip.ip_address} ${var.admin_username}@${azurerm_network_interface.worker_nic[i].private_ip_address}"
  }
}

# Resource Group Name
output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.rg.name
}

# Virtual Network Name
output "vnet_name" {
  description = "Name of the created virtual network"
  value       = azurerm_virtual_network.vnet.name
}

# Storage 
output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.k8s_svc.name
}

output "storage_share_name" {
  value       = azurerm_storage_share.storage_file.name
  description = "Nom du File Share"
}

output "storage_account_id" {
  value       = azurerm_storage_account.k8s_svc.id
  description = "ID du Storage Account"
}

# Next Steps Information
output "next_steps" {
  description = "Instructions for setting up Kubernetes cluster"
  value       = <<-EOT
    
    ========================================
    Kubernetes Cluster Infrastructure Ready!
    ========================================
    
    � Architecture: Bastion Host (1 Public IP)
    
    📋 Access Pattern:
    
    1. Connect to Bastion:
       ssh ${var.admin_username}@${azurerm_public_ip.bastion_pip.ip_address}
    
    2. From Bastion, connect to any node:
       Master-1: ssh ${azurerm_network_interface.master_nic[0].private_ip_address}
       Worker-1: ssh ${azurerm_network_interface.worker_nic[0].private_ip_address}
    
    3. OR use ProxyJump (direct from your PC):
       ssh -J ${var.admin_username}@${azurerm_public_ip.bastion_pip.ip_address} ${var.admin_username}@${azurerm_network_interface.master_nic[0].private_ip_address}
    
    📝 Kubernetes Setup:
    
    1. Initialize Kubernetes on master-1:
       sudo su -
       MASTER_IP=$(hostname -I | awk '{print $1}')
       kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$MASTER_IP --control-plane-endpoint=$MASTER_IP:6443 --upload-certs
    
    2. Configure kubectl:
       mkdir -p /root/.kube
       cp -i /etc/kubernetes/admin.conf /root/.kube/config
    
    3. Install Flannel CNI:
       kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
    
    4. Join other masters and workers using the kubeadm join commands displayed
    
    5. Verify:
       kubectl get nodes
    
    ⚠️  Important Notes:
    - Only the bastion has a public IP
    - All K8s nodes have private IPs only
    - All nodes are pre-configured with kubeadm, kubelet, kubectl, containerd
    - NTP (chrony) synchronized
    - Root access enabled
    
    EOT
}
