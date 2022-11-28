variable "product" {
  type        = string
  description = "Part of naming convention, product/application name."
  default     = "app"
}

variable "env" {
  type        = string
  description = "Which environment is it"
  default     = "dev"
}
variable "env_number" {
  type        = number
  description = "Part of naming convention, number of the environment."
  default     = 1
}