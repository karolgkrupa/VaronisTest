variable "resource_group_name" {
  type = string
}

variable "name_template" {
  type = string
}

variable "vm_password" {
  type      = string
  sensitive = true
}