#!/bin/bash
# filepath: /home/azureuser/kubernets/kubeadm/terraform/import.sh
# Script pour importer les resources Azure existantes dans le state Terraform

set -e

echo "📦 Import des ressources existantes..."
echo ""

cd /home/azureuser/kubernets/kubeadm/terraform

# Configuration
SUBSCRIPTION_ID="ef90f1f8-dfd6-4cd7-81f1-bd37f18abb1e"
TENANT_ID="adf55701-79bd-4548-abec-e0f364c27354"
RG_NAME="k8s-cluster-rg"

echo "Subscription: $SUBSCRIPTION_ID"
echo "Tenant: $TENANT_ID"
echo "Resource Group: $RG_NAME"
echo ""

# Vérifier la connexion
echo "🔐 Vérification de la connexion Azure..."
CURRENT_SUB=$(az account show --query id -o tsv)
CURRENT_TENANT=$(az account show --query tenantId -o tsv)

if [ "$CURRENT_SUB" != "$SUBSCRIPTION_ID" ]; then
  echo "❌ Erreur : Subscription incorrecte"
  echo "   Actuelle: $CURRENT_SUB"
  echo "   Attendue: $SUBSCRIPTION_ID"
  echo ""
  echo "Changez de subscription avec :"
  echo "   az account set --subscription \"$SUBSCRIPTION_ID\""
  exit 1
fi

if [ "$CURRENT_TENANT" != "$TENANT_ID" ]; then
  echo "❌ Erreur : Tenant incorrect"
  echo "   Actuel: $CURRENT_TENANT"
  echo "   Attendu: $TENANT_ID"
  exit 1
fi

echo "✅ Connexion vérifiée"
echo ""

# === IMPORT DES RESOURCES ===

# 1. Resource Group
echo "1️⃣ Import Resource Group..."
terraform import azurerm_resource_group.rg \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}" 2>&1 | grep -i "success\|already" || true

# 2. Virtual Network
echo "2️⃣ Import Virtual Network..."
terraform import azurerm_virtual_network.vnet \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/virtualNetworks/k8s-vnet" 2>&1 | grep -i "success\|already" || true

# 3. Subnet
echo "3️⃣ Import Subnet..."
terraform import azurerm_subnet.k8s_subnet \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/virtualNetworks/k8s-vnet/subnets/k8s-subnet" 2>&1 | grep -i "success\|already" || true

# 4. NSG - Bastion
echo "4️⃣ Import NSG Bastion..."
terraform import azurerm_network_security_group.bastion_nsg \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/networkSecurityGroups/k8s-bastion-nsg" 2>&1 | grep -i "success\|already" || true

# 5. NSG - Master
echo "5️⃣ Import NSG Master..."
terraform import azurerm_network_security_group.master_nsg \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/networkSecurityGroups/k8s-master-nsg" 2>&1 | grep -i "success\|already" || true

# 6. NSG - Worker
echo "6️⃣ Import NSG Worker..."
terraform import azurerm_network_security_group.worker_nsg \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/networkSecurityGroups/k8s-worker-nsg" 2>&1 | grep -i "success\|already" || true

# 7. Public IP - Bastion
echo "7️⃣ Import Public IP Bastion..."
terraform import azurerm_public_ip.bastion_pip \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/publicIPAddresses/k8s-bastion-pip" 2>&1 | grep -i "success\|already" || true

# 8. NIC - Bastion
echo "8️⃣ Import NIC Bastion..."
terraform import azurerm_network_interface.bastion_nic \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/networkInterfaces/k8s-bastion-nic" 2>&1 | grep -i "success\|already" || true

# 9. NSG Association - Bastion
echo "9️⃣ Import NSG Association Bastion..."
terraform import azurerm_network_interface_security_group_association.bastion_nsg_assoc \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/networkInterfaces/k8s-bastion-nic|/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/networkSecurityGroups/k8s-bastion-nsg" 2>&1 | grep -i "success\|already" || true

# 10. Bastion VM
echo "🔟 Import Bastion VM..."
terraform import azurerm_linux_virtual_machine.bastion \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Compute/virtualMachines/k8s-bastion" 2>&1 | grep -i "success\|already" || true

# 11. Master NIC (si multiple)
echo "1️⃣1️⃣ Import Master NIC..."
terraform import 'azurerm_network_interface.master_nic[0]' \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/networkInterfaces/k8s-master-1-nic" 2>&1 | grep -i "success\|already" || true

# 12. Master NSG Association
echo "1️⃣2️⃣ Import Master NSG Association..."
terraform import 'azurerm_network_interface_security_group_association.master_nsg_assoc[0]' \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/networkInterfaces/k8s-master-1-nic|/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/networkSecurityGroups/k8s-master-nsg" 2>&1 | grep -i "success\|already" || true

# 13. Master VM
echo "1️⃣3️⃣ Import Master VM..."
terraform import 'azurerm_linux_virtual_machine.master[0]' \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Compute/virtualMachines/k8s-master-1" 2>&1 | grep -i "success\|already" || true

# 14. Worker NIC
echo "1️⃣4️⃣ Import Worker NIC..."
terraform import 'azurerm_network_interface.worker_nic[0]' \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/networkInterfaces/k8s-worker-1-nic" 2>&1 | grep -i "success\|already" || true

# 15. Worker NSG Association
echo "1️⃣5️⃣ Import Worker NSG Association..."
terraform import 'azurerm_network_interface_security_group_association.worker_nsg_assoc[0]' \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/networkInterfaces/k8s-worker-1-nic|/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/networkSecurityGroups/k8s-worker-nsg" 2>&1 | grep -i "success\|already" || true

# 16. Worker VM
echo "1️⃣6️⃣ Import Worker VM..."
terraform import 'azurerm_linux_virtual_machine.worker[0]' \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Compute/virtualMachines/k8s-worker-1" 2>&1 | grep -i "success\|already" || true

# 17. Storage Account
echo "1️⃣7️⃣ Import Storage Account..."
terraform import azurerm_storage_account.k8s_svc \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Storage/storageAccounts/k8ssvc" 2>&1 | grep -i "success\|already" || true

# 18. Storage File Share - k8s-storage
echo "1️⃣8️⃣ Import Storage File Share (k8s-storage)..."
terraform import azurerm_storage_share.storage_file \
  "https://k8ssvc.file.core.windows.net/k8s-storage" 2>&1 | grep -i "success\|already" || true

# 19. Storage File Share - mysql-storage
echo "1️⃣9️⃣ Import Storage File Share (mysql-storage)..."
terraform import azurerm_storage_share.storage_file_mysql \
  "https://k8ssvc.file.core.windows.net/mysql-storage" 2>&1 | grep -i "success\|already" || true

# 20. Storage File Share - wordpress-storage
echo "2️⃣0️⃣ Import Storage File Share (wordpress-storage)..."
terraform import azurerm_storage_share.storage_file_wordpress \
  "https://k8ssvc.file.core.windows.net/wordpress-storage" 2>&1 | grep -i "success\|already" || true

# 21. Federated Identity Credential - Controller
echo "2️⃣1️⃣ Import Federated Identity Credential (Controller)..."
terraform import azurerm_federated_identity_credential.storage_fic_controller \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/k8s-storage-identity/federatedIdentityCredentials/k8s-storage-federation-controller" 2>&1 | grep -i "success\|already" || true

# 22. Federated Identity Credential - Node
echo "2️⃣2️⃣ Import Federated Identity Credential (Node)..."
terraform import azurerm_federated_identity_credential.storage_fic_node \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/k8s-storage-identity/federatedIdentityCredentials/k8s-storage-federation-node" 2>&1 | grep -i "success\|already" || true

# 23. Master VM Shutdown Schedule
echo "2️⃣3️⃣ Import Master VM Shutdown Schedule..."
terraform import 'azurerm_dev_test_global_vm_shutdown_schedule.master_shutdown_schedule[0]' \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.DevTestLab/schedules/shutdown-computevm-k8s-master-1" 2>&1 | grep -i "success\|already" || true

# 24. Get role assignment IDs for blob reader
echo "2️⃣4️⃣ Import Role Assignment (Storage Blob Data Reader)..."
BLOB_READER_ID=$(az role assignment list \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Storage/storageAccounts/k8ssvc" \
  --query "[?roleDefinitionName=='Storage Blob Data Reader'].id" -o tsv 2>/dev/null | head -1)

if [ -n "$BLOB_READER_ID" ]; then
  terraform import azurerm_role_assignment.storage_blob_reader \
    "$BLOB_READER_ID" 2>&1 | grep -i "success\|already" || true
else
  echo "   ⚠️  Role assignment not found (may need manual creation)"
fi

# 25. Get role assignment IDs for SMB contributor
echo "2️⃣5️⃣ Import Role Assignment (Storage File Data SMB Share Contributor)..."
SMB_CONTRIB_ID=$(az role assignment list \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Storage/storageAccounts/k8ssvc" \
  --query "[?roleDefinitionName=='Storage File Data SMB Share Contributor'].id" -o tsv 2>/dev/null | head -1)

if [ -n "$SMB_CONTRIB_ID" ]; then
  terraform import azurerm_role_assignment.storage_smb_contributor \
    "$SMB_CONTRIB_ID" 2>&1 | grep -i "success\|already" || true
else
  echo "   ⚠️  Role assignment not found (may need manual creation)"
fi

echo ""
echo "✅ Import terminé !"
echo ""
echo "🔍 Vérification avec terraform plan..."
terraform plan -var-file="terraform.tfvars" 2>&1 | tail -30

echo ""
echo "📊 Résumé des resources importées :"
terraform state list 2>&1 | grep -v "^$" || echo "Aucune resource trouvée"

echo ""
echo "📝 Prochaines étapes :"
echo "   - Vérifier le plan avec : terraform plan -var-file=\"terraform.tfvars\""
echo "   - Si aucun changement : terraform apply -var-file=\"terraform.tfvars\""