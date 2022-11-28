variable "resource_group_name" {
  type = string
}

variable "vnet_name" {
  type = string
}

variable "name_template" {
  type = string
}

variable "availability_set" {
  type = string
}

variable "subnet_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vm_password" {
  type      = string
  sensitive = true
}