output "public_ip" {
  value = {
    name           = azurerm_public_ip.this.name
    resource_group = data.azurerm_resource_group.this.name
  }
}