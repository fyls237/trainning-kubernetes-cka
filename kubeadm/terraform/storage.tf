resource "azurerm_storage_account" "k8s_svc" {
  resource_group_name = var.resource_group_name
  name = "k8ssvc"
  location = var.location
  account_tier = "Standard"
  account_replication_type = "GRS"

  azure_files_authentication {
    directory_type = "AADKERB" 
  }

  network_rules {
    default_action = "Deny"
    ip_rules = [var.admin_source_ip]
    virtual_network_subnet_ids = [azurerm_subnet.k8s_subnet.id]
    bypass = [ "AzureServices" ]
  }

  tags = {
    Environment = "Kubernetes"
    Role        = "Storage"
  }
}


resource "azurerm_storage_share" "storage_file" {
  name = "k8s-storage"
  storage_account_name = azurerm_storage_account.k8s_svc.name
  quota = "50"
}

# Managed Identity for Storage Access
resource "azurerm_user_assigned_identity" "storage_identity" {
  resource_group_name = var.resource_group_name
  location = var.location
  name = "k8s-storage-identity"

  tags = {
    Environment = "Kubernetes"
    Role        = "StorageAccess"
  }
  
}

# Federated Identity Credential for Workload Identity
resource "azurerm_federated_identity_credential" "storage_fic" {
  name                       = "k8s-storage-federation"
  resource_group_name        = azurerm_resource_group.rg.name
  parent_id =  azurerm_user_assigned_identity.storage_identity.id
  audience = ["api://AzureADTokenExchange"]
  issuer = "https://kubernetes.default.svc.cluster.local"
  subject = "system:serviceaccount:default:storage-sa"
}

# Role Assignment to allow the Managed Identity to access the Storage Account
resource "azurerm_role_assignment" "storage_blob_reader" {
  scope                = azurerm_storage_account.k8s_svc.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.storage_identity.principal_id
  
}

# RBAC SMS access for the storage account
resource "azurerm_role_assignment" "storage_smb_contributor" {
  scope                = azurerm_storage_account.k8s_svc.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = azurerm_user_assigned_identity.storage_identity.principal_id
}