# Application Gateway: Keyvault integration, App service integration, End-to-End SSL, few common issues and more

## Introduction

Application Gateway is one of the most popular products offered by Azure. It is very powerful and sometimes can be an essential piece for some applications out there. Configuring and managing some of the features it offers can often be a a huge challenge for customers. In this lab, we'll be experimenting and configuring some of those features like: End-to-End TLS termination, Keyvault integration, App service integration as backend., and also we'll be covering a few of the issues that we are noticing from the customers.

## Prerequisites and architecture

In order to complete this lab, there are quite of resources needed:

- A domain name - Cheap domain names: [GoDaddy](https://www.godaddy.com/domains),[NameCheap](https://www.namecheap.com/domains/)
- SSL certificate if you choose not to use a self-signed certificate
- A valid Azure subscription
- Terraform
- Git
- Knowing how application gateway works

Different case scenarios will be implemented, few tasks and questions will be covered to make sure that we all understand the concept and the configuration. Below is the architecture we'll be working with and it will be changing based on the scenario studied.

![Architecture](https://github.com/Tchimwa/Appgw-Keyvault-Private-Endpoint-With-Custom-DNS/blob/main/images/Architecture.png)

## Deployment

Deployment can be done from Azure Cloud Shell or any terminal connected to Azure (VS Code, PowerShell, etc..). Not using Azure Cloud Shell will require Git, Terraform, Az Powershell modules or AzCLI installed. Feel free to change the locations on the _variables.tf_. The default values are _eastus_ and _centralus_.

```typescript
git clone https://github.com/Tchimwa/Appgw-Gateway-Features-Lab.git
cd ./Appgw-Gateway-Features-Lab
terraform init
terraform plan
terraform apply
```

## Case scenarios

### End-to-end TLS Termination with a Multi-site listener

Looking at the default configuration, we have an End-to-End SSL termination with a multi-site listener named "_https-traffic_", the Backend HTTP settings "_appgwkv-https-settings_" using the routing rule "_appgwkv-https-rule_" and connected to the backend pool  "_appgwkv-pool_" that is currently hosting couple web servers serving 3 hostnames : _**www.ced-sougang.com, netdata.ced-sougang.com, labtime.ced-sougang.com**_.

1. What is the particularity of the End-to-End SSL termination?
2. What is the difference between the E2E and the SSL Offload?
3. Looking at the configuration, how will you change the E2E to SSL Offload?
4. What is the difference between the _Basic, Multi-site/Single_ and _Multi-site/multiple-or-wildcard_ listeners?

**Task:** Please configure the HTTP and HTTPS probes to monitor the backend pool.

- HTTPS probe

```typescript
# Create the HTTPS probe
az network application-gateway probe create --gateway-name "tcs-appgw-kv" \
                                            --name "https-probe" \
                                            --path "/" \
                                            --protocol Https \
                                            --resource-group "tcs-appgwkv-rg" \
                                            --host "labtime.ced-sougang.com" \
                                            --host-name-from-http-settings false \
                                            --interval 30 \
                                            --match-status-codes "200-399" \
                                            --threshold 3 \
                                            --timeout 30 \

# Update HTTP settings to use a new probe
az network application-gateway http-settings update --gateway-name "tcs-appgw-kv" \
                                                                                    --name "appgwkv-https-settings" \
                                                                                    --probe "https-probe" \
                                                                                    --resource-group "tcs-appgwkv-rg" \
```

- HTTP probe

```typescript
# Create the HTTP probe
az network application-gateway probe create --gateway-name "tcs-appgw-kv" \
                                            --name "http-probe" \
                                            --path "/" \
                                            --protocol Http \
                                            --resource-group "tcs-appgwkv-rg" \
                                            --host "www.ced-sougang.com" \
                                            --host-name-from-http-settings false \
                                            --interval 30 \
                                            --match-status-codes "200-399" \
                                            --threshold 3 \
                                            --timeout 30 \

# Update HTTP settings to use a new probe
az network application-gateway http-settings update --gateway-name "tcs-appgw-kv" \
                                                                                    --name "appgwkv-http-settings" \
                                                                                    --probe "http-probe" \
                                                                                    --resource-group "tcs-appgwkv-rg" \
```

### Webapp integration with Application Gateway

Keyvault Private endpoint with couple scenarios: Private endpoint and custom-dns server within the same VNET, custom-dns and Private endpoint in two different VNETs.
