output "appgw-fe-ip" {
    value = azurerm_public_ip.appgw-pip.ip_address
    description = "Appgw frontend IP address"  
}

output "webapp-url" {
    value = "https://${azurerm_app_service.webapp.default_site_hostname}"
    description = "Webapp URL "  
}