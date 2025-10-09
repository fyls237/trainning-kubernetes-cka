# Bastion Host - Single Public IP for SSH Jump
resource "azurerm_public_ip" "bastion_pip" {
  name                = "k8s-bastion-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = "Kubernetes"
    Role        = "Bastion"
  }
}

resource "azurerm_network_interface" "bastion_nic" {
  name                = "k8s-bastion-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.k8s_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bastion_pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "bastion_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.bastion_nic.id
  network_security_group_id = azurerm_network_security_group.bastion_nsg.id
}

resource "azurerm_linux_virtual_machine" "bastion" {
  name                = "k8s-bastion"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.bastion_vm_size
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.bastion_nic.id
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

  custom_data = base64encode(file("${path.module}/cloud-init-bastion.yaml"))

  tags = {
    Environment = "Kubernetes"
    Role        = "Bastion"
  }
}
