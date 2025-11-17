# data "azurerm_client_config" "current" {}

# resource "random_string" "kv_suffix" {
#   length = 6
#   special = false
#   upper = false
# }

# resource "azurerm_key_vault" "k8s_kv" {
#   name = "k8s-kv-${random_string.kv_suffix.result}"
#   location = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name
#   tenant_id = data.azurerm_client_config.current.tenant_id
#   sku_name =  "standard"
#   soft_delete_retention_days = 7
#   purge_protection_enabled = false

#  # Requis pour workload identity
#   enable_rbac_authorization = true

# }