#!/bin/bash
# filepath: /home/azureuser/kubernets/kubeadm/scripts/import-missing-resources.sh

set -e

echo "📦 Import des ressources manquantes..."
echo ""

cd /home/azureuser/kubernets/kubeadm/terraform

SUBSCRIPTION_ID="ef90f1f8-dfd6-4cd7-81f1-bd37f18abb1e"
RG_NAME="k8s-cluster-rg"

# 1. Master NIC
echo "1️⃣ Import Master NIC..."
terraform import 'azurerm_network_interface.master_nic[0]' \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/networkInterfaces/k8s-master-1-nic"

# 2. NSG Association - Bastion
echo "2️⃣ Import Bastion NSG Association..."
terraform import azurerm_network_interface_security_group_association.bastion_nsg_assoc \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/networkInterfaces/k8s-bastion-nic|/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/networkSecurityGroups/k8s-bastion-nsg"

# 3. NSG Association - Master
echo "3️⃣ Import Master NSG Association..."
terraform import 'azurerm_network_interface_security_group_association.master_nsg_assoc[0]' \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/networkInterfaces/k8s-master-1-nic|/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/networkSecurityGroups/k8s-master-nsg"

# 4. NSG Association - Worker
echo "4️⃣ Import Worker NSG Association..."
terraform import 'azurerm_network_interface_security_group_association.worker_nsg_assoc[0]' \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/networkInterfaces/k8s-worker-1-nic|/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/networkSecurityGroups/k8s-worker-nsg"

# 5. Master VM (si pas déjà importée)
echo "5️⃣ Import Master VM..."
terraform import 'azurerm_linux_virtual_machine.master[0]' \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Compute/virtualMachines/k8s-master-1" 2>&1 | grep -v "Resource already managed" || echo "  ✅ Déjà importée"

echo ""
echo "✅ Import terminé !"
echo ""
echo "🔍 Vérification avec terraform plan..."
terraform plan

echo ""
echo "📝 Si tout est OK, applique avec: terraform apply"