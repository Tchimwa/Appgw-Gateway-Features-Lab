terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.97.0"
    }
  }
  required_version = "0.14.4"
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
  name     = "${var.init}-appgwkv-rg"
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
  name                 = "apps-sbnt"
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
  name                 = "pe-dns-sbnt"
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
  name                = "${var.init}-appgwkv-pip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "bst-pip" {
  name                = "${var.init}-appgwkv-bst-pip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bst-host" {
  name                = "${var.init}-appgwkv-bst"
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
  name                            = "${var.init}-web0${count.index + 1}"
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
  name                = "${var.init}-dns0${count.index + 1}"
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
  name                = "${var.init}-appgw"
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

  frontend_port {
    name = "https-443"
    port = 443
  }

  frontend_ip_configuration {
    name = "appgwkv-feconf"
    public_ip_address_id = azurerm_public_ip.appgw-pip.id
  }

  backend_address_pool {
    name = "appgwkv-pool"
  }

  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.appgw_umi.id]
  }

  ssl_certificate {
    name = "wildcard_ced-sougang_com"
    key_vault_secret_id = azurerm_key_vault_certificate.kv_cert.secret_id
  }

    backend_http_settings {
    name                  = "appgwkv-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60    
    pick_host_name_from_backend_address = false
  }

  backend_http_settings {
    name                  = "appgwkv-https-settings"
    cookie_based_affinity = "Disabled"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 60    
    pick_host_name_from_backend_address = false
  }

  http_listener {
    name                           = "http-traffic"
    frontend_ip_configuration_name = "appgwkv-feconf"
    frontend_port_name             = "http-80"
    protocol                       = "Http"
    host_names = [ "*.ced-sougang.com" ]    
  }

    http_listener {
    name                           = "https-traffic"
    frontend_ip_configuration_name = "appgwkv-feconf"
    frontend_port_name             = "https-443"
    protocol                       = "Https"
    host_names = [ "*.ced-sougang.com" ] 
    ssl_certificate_name = "wildcard_ced-sougang_com"
  }  

  request_routing_rule {
    name                       = "appgwkv-http-rule"
    rule_type                  = "Basic"
    http_listener_name         = "http-traffic"
    backend_address_pool_name  = "appgwkv-pool"
    backend_http_settings_name = "appgwkv-http-settings"
    priority = "100"
  }

  request_routing_rule {
    name                       = "appgwkv-https-rule"
    rule_type                  = "Basic"
    http_listener_name         = "https-traffic"
    backend_address_pool_name  = "appgwkv-pool"
    backend_http_settings_name = "appgwkv-https-settings"
    priority = "200"
  }  

  lifecycle {
    ignore_changes = [
      backend_address_pool,
      backend_http_settings,
      frontend_port,
      http_listener,
      probe,
      request_routing_rule,
      url_path_map,
      ssl_certificate,
      redirect_configuration,
      autoscale_configuration
    ]
  }  
  depends_on = [azurerm_key_vault_certificate.kv_cert]
}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "appgwnic-assoc" {
  count                   = length (var.location)
  network_interface_id    = azurerm_network_interface.appvmnic[count.index].id
  ip_configuration_name   = "web0${count.index + 1}-ipcfg"
  backend_address_pool_id = azurerm_application_gateway.appgw_web.backend_address_pool[0].id
}

resource "azurerm_key_vault" "kv" {
  name                        = "${var.init}-appgw-kv"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location[1]
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  enabled_for_disk_encryption = true
  enabled_for_deployment = true
  enabled_for_template_deployment = true

  sku_name = "standard"
}

resource "azurerm_key_vault_certificate" "kv_cert" {
  name         = "${var.init}-wildcard"
  key_vault_id = azurerm_key_vault.kv.id

  certificate {
    contents = filebase64("./certs/wildcard_ced-sougang_com.pfx")
    password = var.cert-password
  }
  depends_on = [azurerm_key_vault_access_policy.user_access]
}

resource "azurerm_user_assigned_identity" "appgw_umi" {
  name                = "${var.init}-appgw-umi"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location[1]
}

resource "azurerm_key_vault_access_policy" "user_access" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id  
  
  key_permissions = [
      "backup",
      "create",
      "decrypt",
      "delete",
      "encrypt",
      "get",
      "import",
      "list",
      "purge",
      "recover",
      "restore",
      "sign",
      "unwrapKey",
      "update",
      "verify",
      "wrapKey",
  ]  
  secret_permissions = [
      "backup",
      "delete",
      "get",
      "list",
      "purge",
      "recover",
      "restore",
      "set",
  ]
  certificate_permissions = [ 
      "create",
      "delete",
      "deleteissuers",
      "get",
      "getissuers",
      "import",
      "list",
      "listissuers",
      "managecontacts",
      "manageissuers",
      "setissuers",
      "update",
  ]
  depends_on = [azurerm_key_vault.kv]
}

resource "azurerm_key_vault_access_policy" "appgwkv_access" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.appgw_umi.principal_id
  
  key_permissions = [
    "get", "list",
  ]  
  secret_permissions = [
    "get", "list",
  ]
  certificate_permissions = [ 
    "get", "list" ]
}

resource "azurerm_app_service_plan" "appserviceplan" {
  name                = "${var.init}-webapp-kv-asp"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location[1]
  kind                = "Linux"
  reserved         =   true

  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_app_service" "webapp" {
  name                = "${var.init}-webapp"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location[1]
  app_service_plan_id = azurerm_app_service_plan.appserviceplan.id

  site_config {
    dotnet_framework_version = "v5.0"
    health_check_path = "/"
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
