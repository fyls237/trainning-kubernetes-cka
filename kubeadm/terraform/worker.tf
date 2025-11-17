# Worker Nodes - Private IPs only
resource "azurerm_network_interface" "worker_nic" {
  count               = var.worker_count
  name                = "k8s-worker-${count.index + 1}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.k8s_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "worker_nsg_assoc" {
  count                     = var.worker_count
  network_interface_id      = azurerm_network_interface.worker_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.worker_nsg.id
}

resource "azurerm_linux_virtual_machine" "worker" {
  count               = var.worker_count
  name                = "k8s-worker-${count.index + 1}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.worker_vm_size
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.worker_nic[count.index].id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    hostname = "k8s-worker-${count.index + 1}"
  }))

  tags = {
    Environment = "Kubernetes"
    Role        = "Worker"
  }
}
<<<<<<< HEAD
=======

resource "azurerm_dev_test_global_vm_shutdown_schedule" "worker_shutdown_schedule" {
  count = var.worker_count
  location            = azurerm_resource_group.rg.location
  virtual_machine_id  = azurerm_linux_virtual_machine.worker[count.index].id
  enabled =  true
  daily_recurrence_time = "0200"
  timezone              = "UTC"

  notification_settings {
    enabled = false
  }

}
>>>>>>> feat/azurefile
