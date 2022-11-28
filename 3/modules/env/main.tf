data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

resource "azurerm_virtual_network" "this" {
  name                = "this-network"
  address_space       = ["10.0.0.0/24"]
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
}

resource "azurerm_subnet" "this" {
  name                 = "default"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_availability_set" "this" {
  location            = data.azurerm_resource_group.this.location
  name                = format(var.name_template, "as", 1)
  resource_group_name = data.azurerm_resource_group.this.name
}

module "vm1" {
  source              = "../linux_vm"
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  subnet_name         = azurerm_subnet.this.name
  vm_password         = var.vm_password
  vnet_name           = azurerm_virtual_network.this.name
  name_template       = format(var.name_template, "%s", 1)
  availability_set    = azurerm_availability_set.this.name
  depends_on          = [
    azurerm_subnet.this
  ]
}

module "vm2" {
  source              = "../linux_vm"
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  subnet_name         = azurerm_subnet.this.name
  vm_password         = var.vm_password
  vnet_name           = azurerm_virtual_network.this.name
  name_template       = format(var.name_template, "%s", 2)
  availability_set    = azurerm_availability_set.this.name
  depends_on          = [
    azurerm_subnet.this
  ]
}
resource "random_string" "dns" {
  length = 8
  min_lower = 8
  special = false
  upper = false
  numeric = false
}

resource "azurerm_public_ip" "this" {
  name                = "PublicIPForLB"
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  allocation_method   = "Static"
  domain_name_label = random_string.dns.result
}

resource "azurerm_lb" "this" {
  name                = "TestLoadBalancer"
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.this.id
  }
}

resource "azurerm_lb_rule" "this" {
  loadbalancer_id                = azurerm_lb.this.id
  name                           = "http"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = azurerm_lb.this.frontend_ip_configuration[0].name
  probe_id                       = azurerm_lb_probe.this.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.this.id]
}

data "azurerm_network_interface" "nic1" {
  name                = module.vm1.nic
  resource_group_name = data.azurerm_resource_group.this.name
  depends_on          = [
    module.vm1
  ]
}

resource "azurerm_network_interface_backend_address_pool_association" "vm1_association" {
  network_interface_id    = data.azurerm_network_interface.nic1.id
  ip_configuration_name   = data.azurerm_network_interface.nic1.ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.this.id
}

data "azurerm_network_interface" "nic2" {
  name                = module.vm2.nic
  resource_group_name = data.azurerm_resource_group.this.name
  depends_on          = [
    module.vm2
  ]
}

resource "azurerm_network_interface_backend_address_pool_association" "vm2_association" {
  network_interface_id    = data.azurerm_network_interface.nic2.id
  ip_configuration_name   = data.azurerm_network_interface.nic2.ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.this.id
}

resource "azurerm_lb_probe" "this" {
  loadbalancer_id = azurerm_lb.this.id
  name            = "http-inbound-probe"
  port            = 80
}

resource "azurerm_lb_backend_address_pool" "this" {
  loadbalancer_id = azurerm_lb.this.id
  name            = "business-backend-pool"
}