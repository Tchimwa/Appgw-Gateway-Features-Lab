variable "location" {
  default = [
    "eastus",
    "centralus",
  ]
}

variable "init" {
  type = string
  description = "Your Initials"
}

variable "cert-password" {
  type        = string
  default     = "Lemannequingros1989#"
  sensitive = true
  description = "PFX certificate password"
}

variable "vnet_address_space" {
  default = [
    "10.90.0.0/16",
    "10.91.0.0/16",
  ]
}

variable "username" {
  type    = string
  default = "netadmin"
  sensitive = true
}

variable "password" {
  type    = string
  default = "Networking2022#"
  sensitive = true
}