variable "location" {
  default = [
    "eastus",
    "centralus",
  ]
}

variable "cert-password" {
  type        = string
  default     = "Lemannequingros1989#"
  description = "PFX certificate password"
}

variable "vnet_address_space" {
  default = [
    "10.89.0.0/16",
    "10.90.0.0/16",
  ]
}

variable "username" {
  type    = string
  default = "netdata"
}

variable "password" {
  type    = string
  default = "Networking2022#"
}