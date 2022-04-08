terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.97.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

data "azurerm_client_config" "current" {}

data "template_file" "web_server" {
  template = file("./scripts/web-https.sh")
}

resource "azurerm_resource_group" "main" {
  name     = "appgwkv-rg"
  location = var.location[0]
}

resource "azurerm_virtual_network" "vnet" {
  count = length(var.location)
  name                = "appgwkv-vnet-0${count.index + 1}"
  resource_group_name = azurerm_resource_group.main.name
  location            = element (var.location, count.index)
  address_space       = [element (var.vnet_address_space, count.index)]
}

resource "azurerm_subnet" "apps" {
  count = length(var.location)
  name                 = "appgw-sbnt"
  virtual_network_name = element(azurerm_virtual_network.vnet.*.name, count.index)
  resource_group_name  = azurerm_resource_group.main.name
  address_prefixes     = [
      cidrsubnet(
          element(azurerm_virtual_network.vnet[count.index].address_space, count.index), 
          8, 
          0,
      )
  ]
}

resource "azurerm_subnet" "vm" {
  count = length(var.location)
  name                 = "vm-sbnt"
  virtual_network_name = element(azurerm_virtual_network.vnet.*.name, count.index)
  resource_group_name  = azurerm_resource_group.main.name
  address_prefixes     = [
      cidrsubnet(
          element(azurerm_virtual_network.vnet[count.index].address_space, count.index), 
          8, 
          1,
      )
  ]
}

resource "azurerm_subnet" "pe" {
  count = length(var.location)
  name                 = "pe-sbnt"
  virtual_network_name = element(azurerm_virtual_network.vnet.*.name, count.index)
  resource_group_name  = azurerm_resource_group.main.name
  address_prefixes     = [
      cidrsubnet(
          element(azurerm_virtual_network.vnet[count.index].address_space, count.index), 
          8, 
          2,
      )
  ]
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  virtual_network_name = azurerm_virtual_network.vnet[0].name
  resource_group_name  = azurerm_resource_group.main.name
  address_prefixes     = [ cidrsubnet(var.vnet_address_space[0], 8, 3) ]
}

resource "azurerm_subnet" "webapp-pe" {
  name                 = "webapp-pe-sbnet"
  virtual_network_name = azurerm_virtual_network.vnet[1].name
  resource_group_name  = azurerm_resource_group.main.name
  address_prefixes     = [ cidrsubnet(var.vnet_address_space[1], 8, 3) ]
}

resource "azurerm_network_security_group" "appgw_nsg" {
  name                = "web-nsg"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  security_rule {
    name                       = "Allow SSH"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow HTTP"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow HTTPS"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "appgw-pip" {
  name                = "appgwkv-pip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "bst-pip" {
  name                = "appgwkv-bst-pip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bst-host" {
  name                = "appgwkv-bst"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                 = "bst-ipcfg"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bst-pip.id
  }
}

resource "azurerm_network_interface" "appvmnic" {
  count               = length(var.location)
  name                = "web0${count.index + 1}-vmnic"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                          = "web0${count.index + 1}-ipcfg"
    subnet_id                     = azurerm_subnet.vm[0].id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost (cidrsubnet(var.vnet_address_space[0], 8, 1), count.index + 101)
    primary                       = true
  }
}

resource "azurerm_network_interface" "dnsvmnic" {
  count               = length(var.location)
  name                = "dns0${count.index + 1}-vmnic"
  resource_group_name = azurerm_resource_group.main.name
  location            = element (var.location, count.index)

  ip_configuration {
    name                          = "dns0${count.index + 1}-ipcfg"
    subnet_id                     = element(azurerm_subnet.pe.*.id, count.index)
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost (cidrsubnet(var.vnet_address_space[count.index], 8, 2), 10)
    primary                       = true
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg-assoc" {
  subnet_id                 = azurerm_subnet.vm[0].id
  network_security_group_id = azurerm_network_security_group.appgw_nsg.id
}


resource "azurerm_linux_virtual_machine" "web" {
  count                           = length(var.location)
  name                            = "web0${count.index + 1}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                            = "Standard_D2s_v3"
  admin_username                  = var.username
  admin_password                  = var.password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.appvmnic[count.index].id]
  computer_name                   = "web0${count.index + 1}"
  custom_data                     = base64encode(data.template_file.web_server.rendered)

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
    disk_size_gb         = 100

  }
}

resource "azurerm_windows_virtual_machine" "dns" {
  count = length(var.location)
  name                = "dns0${count.index + 1}"
  resource_group_name = azurerm_resource_group.main.name
  location            = element (var.location, count.index)
  size                = "Standard_F2"
  admin_username      = var.username
  admin_password      = var.password
  network_interface_ids = [azurerm_network_interface.dnsvmnic[count.index].id]
  custom_data = filebase64("./scripts/dns.ps1")


  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "dns_install" {
  count = length(var.location)  
  name                 = "dns-install"
  virtual_machine_id = azurerm_windows_virtual_machine.dns[count.index].id 
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  settings = <<SETTINGS
    {
        "commandToExecute": "powershell -ExecutionPolicy unrestricted -NoProfile -NonInteractive -command \"cp c:/AzureData/CustomData.bin c:/AzureData/dns.ps1; c:/AzureData/dns.ps1\""
    }
    SETTINGS
}

resource "azurerm_application_gateway" "appgw_web" {
  name                = "appgw-kv"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location


  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2

  }

  gateway_ip_configuration {
    name      = "appgwkv-ipconf"
    subnet_id = azurerm_subnet.apps[0].id
  }

  frontend_port {
    name = "http-80"
    port = 80
  }

  frontend_ip_configuration {
    name = "appgwkv-feconf"
    public_ip_address_id = azurerm_public_ip.appgw-pip.id
  }

  backend_address_pool {
    name = "appgwkv-pool"
  }

  backend_http_settings {
    name                  = "appgwkv-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = "http-traffic"
    frontend_ip_configuration_name = "appgwkv-feconf"
    frontend_port_name             = "http-80"
    protocol                       = "Http"

  }

  request_routing_rule {
    name                       = "appgwkv-http-rule"
    rule_type                  = "Basic"
    http_listener_name         = "http-traffic"
    backend_address_pool_name  = "appgwkv-pool"
    backend_http_settings_name = "appgwkv-settings"
  }
}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "appgwnic-assoc" {
  count                   = length (var.location)
  network_interface_id    = azurerm_network_interface.appvmnic[count.index].id
  ip_configuration_name   = "web0${count.index + 1}-ipcfg"
  backend_address_pool_id = azurerm_application_gateway.appgw_web.backend_address_pool[0].id
}

resource "azurerm_key_vault" "kv" {
  name                        = "kv-appgw"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location[1]
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"
}

resource "azurerm_key_vault_certificate" "kv_cert" {
  name         = "wilcard-cert"
  key_vault_id = azurerm_key_vault.kv.id

  certificate {
    contents = filebase64("./certs/wildcard_ced-sougang_com.pfx")
    password = var.cert-password
  }
}

resource "azurerm_user_assigned_identity" "appgw_umi" {
  name                = "appgw-umi"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location[1]
}

resource "azurerm_key_vault_access_policy" "appgwkv_access" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.appgw_umi.principal_id
  
  key_permissions = [
    "Get", "List",
  ]  
  secret_permissions = [
    "Get", "List",
  ]
}

resource "azurerm_app_service_plan" "appserviceplan" {
  name                = "webapp-kv-asp"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location[1]
  kind = "Linux"  
  sku {
    tier = "Free"
    size = "F1"
  }
}

resource "azurerm_app_service" "webapp" {
  name                = "webapp-kv"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location[1]
  app_service_plan_id = azurerm_app_service_plan.appserviceplan.id
  site_config {
    linux_fx_version = "DOTNETCORE|3.1"
  }
}

resource "azurerm_virtual_network_peering" "peering" {
  count   = length(var.location)
  name   = "Peering-to-${element(azurerm_virtual_network.vnet.*.name, 1 - count.index)}"
  resource_group_name = azurerm_resource_group.main.name
  virtual_network_name         = element(azurerm_virtual_network.vnet.*.name, count.index)
  remote_virtual_network_id    = element(azurerm_virtual_network.vnet.*.id, 1 - count.index)
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit = false
}