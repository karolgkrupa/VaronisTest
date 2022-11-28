locals {
  name_template = "%s-%s-%s-%02d"
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}
data "azurerm_subnet" "this" {
  name                = var.subnet_name
  resource_group_name = data.azurerm_resource_group.this.name
  virtual_network_name = var.vnet_name
}

resource "azurerm_network_interface" "this" {
  name                = format(var.name_template, "nic")
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"
  }
}

data "template_cloudinit_config" "this" {
  gzip          = true
  base64_encode = true

  part {

    content_type = "text/cloud-config"
    content      = "packages: ['nginx']"
  }
}

data "azurerm_availability_set" "this" {
  name                = var.availability_set
  resource_group_name = data.azurerm_resource_group.this.name
}

resource "azurerm_linux_virtual_machine" "this" {
  name                = format(var.name_template, "vm")
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  size                = "Standard_B1ms"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.this.id,
  ]

  disable_password_authentication = false
  admin_password = var.vm_password
  availability_set_id = data.azurerm_availability_set.this.id

  custom_data = data.template_cloudinit_config.this.rendered

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
}