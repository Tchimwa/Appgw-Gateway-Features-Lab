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
- [PSPING](https://docs.microsoft.com/en-us/sysinternals/downloads/psping) on the VM **dns-01**

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

### Assumptions

- Both DNS servers already have 169.63.29.16 as forwarder
- The initials used in this lab are mine **"tcs"**, so yours will be different and your resources' name as well
- The certificate used here is my personal certificate and I manage the CN domain name. You can use yours and make some changes on the script and the configuration

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
az network application-gateway probe create --gateway-name "tcs-appgw" \
                                            --name "https-probe" \
                                            --path "/" \
                                            --protocol Https \
                                            --resource-group "tcs-appgwkv-rg" \
                                            --host "labtime.ced-sougang.com" \
                                            --host-name-from-http-settings false \
                                            --interval 30 \
                                            --match-status-codes "200-399" \
                                            --threshold 3 \
                                            --timeout 30

# Update HTTP settings to use a new probe
az network application-gateway http-settings update --gateway-name "tcs-appgw" \
                                                    --name "appgwkv-https-settings" \
                                                    --probe "https-probe" \
                                                    --enable-probe true \
                                                    --resource-group "tcs-appgwkv-rg" 
```

- HTTP probe

```typescript
# Create the HTTP probe
az network application-gateway probe create --gateway-name "tcs-appgw" \
                                            --name "http-probe" \
                                            --path "/" \
                                            --protocol Http \
                                            --resource-group "tcs-appgwkv-rg" \
                                            --host "www.ced-sougang.com" \
                                            --host-name-from-http-settings false \
                                            --interval 30 \
                                            --match-status-codes "200-399" \
                                            --threshold 3 \
                                            --timeout 30

# Update HTTP settings to use a new probe
az network application-gateway http-settings update --gateway-name "tcs-appgw" \
                                                    --name "appgwkv-http-settings" \
                                                    --probe "http-probe" \
                                                    --enable-probe true \
                                                    --resource-group "tcs-appgwkv-rg"
```

### Webapp integration with Application Gateway

#### Add the backend pool for the Webapp

Here, we'll be adding the webapp to the backend pool using his hostname:

```typescript
az network application-gateway address-pool create --gateway-name "tcs-appgw" \
                                                   --name "webapp-pool" \
                                                   --resource-group "tcs-appgwkv-rg" \
                                                   --servers "tcs-webapp.azurewebsites.net" 
```

#### Create the backend settings and the probe

The HTTPS probe:

```typescript
az network application-gateway probe create --gateway-name "tcs-appgw" \
                                            --name "webapp-probe" \
                                            --path "/" \
                                            --protocol Https \
                                            --resource-group "tcs-appgwkv-rg" \
                                            --host-name-from-http-settings true \
                                            --interval 30 \
                                            --match-status-codes "200-399" \
                                            --threshold 3 \
                                            --timeout 30 
```

The backend settings here will be set up with HTTPS as it is currently the protocol supported by the webapp.

```typescript
az network application-gateway http-settings create --gateway-name "tcs-appgw" \
                                                    --name "webapp-https-settings" \
                                                    --port 443 \
                                                    --resource-group "tcs-appgwkv-rg" \
                                                    --host-name-from-backend-pool true \
                                                    --timeout 30 \
                                                    --protocol Https \
                                                    --enable-probe true \
                                                    --probe "webapp-probe" \
                                                    --cookie-based-affinity Disabled
```

#### Create a HTTPS listener and the routing rule

Adding a HTTPS listener attached to the public Frontend IP, and replace your initials in the commands.

```typescript
az network application-gateway http-listener create --frontend-port "https-443" \
                                                    --gateway-name "tcs-appgw" \
                                                    --name "webapp-https" \
                                                    --resource-group "tcs-appgwkv-rg" \
                                                    --frontend-ip "appgwkv-feconf" \
                                                    --host-name "tcs-webapp.ced-sougang.com" \
                                                    --ssl-cert wildcard_ced-sougang_com
```

Adding the routing rule with the priority 500.

```typescript
az network application-gateway rule create --gateway-name "tcs-appgw" \
                                           --name "webapp-rule" \
                                           --resource-group "tcs-appgwkv-rg" \
                                           --address-pool "webapp-pool" \
                                           --http-listener "webapp-https" \
                                           --http-settings "webapp-https-settings" \
                                           --priority 500 \
                                           --rule-type Basic
```

**Tasks:**

- Create an A record with the hostname <**_initials>-webapp.ced-sougang.com_** and the public IP address of the Application Gateway.
- Access the URL: _**https://<_initials>-webapp.ced-sougang.com_**_ and explain why we are getting the contents of _<https://www.ced-sougang.com>_ instead of the web app content.
- What can be the issue here and how to resolve it?

    _Hint: Check the routing priority_
- Change the priority of the routing named "webapp-rule" to 10, and try to access the URL again. Can you explain the changes?

```typescript
az network application-gateway rule update  --resource-group "tcs-appgwkv-rg" \
                                                                        --gateway-name "tcs-appgw" \
                                                                        --name "webapp-rule" \
                                                                        --priority 10 
```

### KeyVault Integration

Here we'll review the requirements and the most important points when it comes to the KeyVault integration with the Application Gateway.

- What are the network requirements when it comes to the KeyVault integration with the AppGW?
- What are the DNS requirements?
- What are the access policies required for the integration?

**Tasks:**

- Restrict the network access to the KV to your Application Gateway subnet
- Explain the access policies configured on the KeyVault
- What is the goal of the service endpoint configured while restricting access to the AppGW?

### Implications with the private endpoint on the KeyVault and the WebApp

I've noticed some lack of misunderstanding with customers when it comes to associating the AppGW with the KV and the webapp using the private endpoint. Here, we will go through couple scenarios to demonstrate what is actually happening for each scenario.

#### Create a private endpoint on the KeyVault and WebApp resources

It is important to mention that so far we've been using the "Default(Azure-provided)" as DNS configuration on both VNETs.

![DefaultAzureDNS](https://github.com/Tchimwa/Appgw-Keyvault-Private-Endpoint-With-Custom-DNS/blob/main/images/DefaultAzureDNS.png)

Using the portal, we'll be creating the PE from each resources using the **"Networking"** tab located on left panel of each resource page.

- KeyVault - Private Endpoint named "kv-pe";
- WebApp - Private endpoint named "webapp-pe"

**Tasks:**

- Using the Connection Troubleshoot from the AppGW, please try to access each hostname and pay attention to the IP address resolving to the request.
  - KeyVault: **tcs-appgw-kv.vault.azure.net**
  - WebApp: **tcs-webapp.azurewebsites.net**

![ConnectionTB](https://github.com/Tchimwa/Appgw-Keyvault-Private-Endpoint-With-Custom-DNS/blob/main/images/ConnectionTB.png)

- Why is the AppGW not resolving with the Private Endpoint IP Address of each resource?
- What are the implications of this DNS resolution on the KV integration?
- Check the probes, what do you notice? Can you explain what is currently happening?
    _Hint: Check this [link](https://docs.microsoft.com/en-us/azure/app-service/networking/private-endpoint?msclkid=d93d4e90bed111ec9d5286eeb78023c9)_.
- How do we resolve that issue?
    _Hint: virtual links_
- From the VM named "dns-01" using the credentials above, run the following commands to verify the DNS resolution throughout the custom DNS. From the browser launch <https://tcs-webapp.azurewebsites.net>.

```typescript
nslookup tcs-appgw-kv.vault.azure.net
nslookup tcs-webapp.azurewebsites.net
```

- From the AppGW page, use the **Connection Troubleshoot** to test the traffic, and see if the AppGW is resolving to Private Endpoint of each resource.
- From the "webapp-probe", you might have to make a change to trigger the update.

#### Custom DNS scenarios

##### AppGW not sharing the same VNET with the custom DNS server on Azure

Here, we will have our DNS server on a different VNET than our Application Gateway as you can see on the pick below:

![Scenario01](https://github.com/Tchimwa/Appgw-Keyvault-Private-Endpoint-With-Custom-DNS/blob/main/images/Scenario01.png)

VM credentials:

- **Username:** netadmin
- **Password:** Networking2022#

**Tasks:**

- From both private zones, remove the virtual links to the **"appgwkv-vnet-01"** so we can have the original scenario.
- Change the DNS servers on both VNETs to use the custom DNS server **"dns-02"** with the IP address **10.91.2.10**.
- Restart both VM: **dns-01** and **dns-02**
- From the VM named "dns-01" using the credentials above, run the following commands to verify the DNS resolution throughout the custom DNS. From the browser launch <https://tcs-webapp.azurewebsites.net>.

```typescript
nslookup tcs-appgw-kv.vault.azure.net
nslookup tcs-webapp.azurewebsites.net
```

- What do you notice?
- Are those the results expected? Explain why.
- Check the KV firewall and make sure that it is restricted to allow access to the AppGW subnet only.
- From "dns-01", use PSPing and to test th traffic on both PE using their hostname and conclude.

```typescript
psping tcs-appgw-kv.vault.azure.net:443
psping  tcs-webapp.azurewebsites.net:443
```

- Try to restart the AppGW to apply the DNS change using the commands below

```typescript
az network application-gateway stop -g "tcs-appgwkv-rg" -n "tcs-appgw"
az network application-gateway start -g "tcs-appgwkv-rg" -n "tcs-appgw"
```

- Using the **Connection Troubleshoot** tool from the AppGW, please do the test traffic on each hostname and pay attention to the IP address resolving to the request.
  - KeyVault: **tcs-appgw-kv.vault.azure.net**
  - WebApp: **tcs-webapp.azurewebsites.net**

What do you notice and how to resolve the issue?

**Resolution:**

This is a current issue when it comes to the AppGw integration with KV using the Private Endpoint. It seems not to care about custom DNS in this scenario. In order to resolve this issue, we simply have to create a virtual link between the private zone **"privatelink.vaultcore.azure.net"** and the VNET hosting the AppGW which is **"appgwkv-vnet-01"** in this case.

![Scenario01Resolution](https://github.com/Tchimwa/Appgw-Keyvault-Private-Endpoint-With-Custom-DNS/blob/main/images/Scenario01Resolution.png)

From 2 different PaaS services using the private endpoint, we have couple different behaviors from the AppGW. It seems to ignore the custom DNS when it comes to the KV, but it seems not to have any issue with the WebApp. Also, the KV firewall seems not to be applied on the Private endpoint connection.

##### AppGW sharing the same VNET with the custom DNS server on Azure

Here, we will have our DNS server on the same VNET with our Application Gateway as you can see on the pick below:

![Scenario02](https://github.com/Tchimwa/Appgw-Keyvault-Private-Endpoint-With-Custom-DNS/blob/main/images/Scenario02.png)

**Tasks:**

- From both private zones, remove the virtual links to the "appgwkv-vnet-01" so we can have the original scenario.
- Change the DNS servers on both VNETs to use the custom DNS server **"dns-01"** with the IP address **10.90.2.10**.
- Restart both VM: **dns-01** and **dns-02**
- From the VM named "dns-01" using the credentials above, run the following commands to verify the DNS resolution throughout the custom DNS.

```typescript
nslookup tcs-appgw-kv.vault.azure.net
nslookup tcs-webapp.azurewebsites.net
```

- What do you notice?
- Are those the results expected? Explain why.
- Try to restart the AppGW to apply the DNS change using the commands below

```typescript
az network application-gateway stop -g "tcs-appgwkv-rg" -n "tcs-appgw"
az network application-gateway start -g "tcs-appgwkv-rg" -n "tcs-appgw"
```

- Using the **Connection Troubleshoot** tool from the AppGW, please do the test traffic on each hostname and pay attention to the IP address resolving to the request.
  - KeyVault: **tcs-appgw-kv.vault.azure.net**
  - WebApp: **tcs-webapp.azurewebsites.net**

**AppGW issue resolution:** Create a virtual link between the private zone **"privatelink.vaultcore.azure.net"** and the VNET hosting the AppGW and the DNS server which is **"appgwkv-vnet-01"** in this case.

- Check the probe named "webapp-probe", is it in the Healthy State?
- From the browser launch <https://tcs-webapp.azurewebsites.net>, is it successful? Why?
- Use the Connection Troubleshoot to check if the AppGW is resolving to the WebApp Private Endpoint IP Address as it should with a PE.
- How do you resolve the issue?

**Resolution:**

Since the PE were created on a different VNET which is **appgwkv-vnet-02**, the virtual links are automatically created with the VNET hosting the PE. With a custom DNS server on a different VNET, that DNS doesn't have any link to the private zones so it is unable to query them and get the records for both Private Endpoints. To resolve the issue, we need to create a virtual link between the VNET hosting the custom DNS and the private zones. A virtual link will be create between **appgwkv-vnet-01** and both private zones as you can see on the pic below.

![Scenario02Resolution](https://github.com/Tchimwa/Appgw-Keyvault-Private-Endpoint-With-Custom-DNS/blob/main/images/Scenario02Resolution.png)

- Let's check the probes to see if the probe "webapp-probe" is back to the Healthy State.
- Use the Connection Troubleshoot to check if the AppGW is resolving to the WebApp Private Endpoint IP Address.

### Redirection feature - HTTP to HTTPS on the WebApp listener

Usually redirection from HTTP to HTTPS is done through 3 steps since the HTTPS was already created:

- Adding the HTTPS listener

```typescript
az network application-gateway http-listener create \
                      --name "webapp-http" \
                      --frontend-ip "appgwkv-feconf" \
                      --frontend-port "http-80" \
                      --resource-group "tcs-appgwkv-rg" \
                      --gateway-name "tcs-appgw"
```

- Add the redirection configuration

```typescript
az network application-gateway redirect-config create \
                        --name "webapp-http_to_https" \
                        --gateway-name "tcs-appgw" \
                        --resource-group "tcs-appgwkv-rg" \
                        --type Permanent \
                        --target-listener "webapp-https" \
                        --include-path true \
                        --include-query-string true
```

- Create the routing rule

```typescript
az network application-gateway rule create \
                      --gateway-name "tcs-appgw" \
                      --name "webapp-redirect" \
                      --resource-group "tcs-appgwkv-rg" \
                      --http-listener "webapp-http" \
                      --rule-type Basic \
                      --redirect-config "webapp-http_to_https" \
                      --priority 20
```

The successful test below is showing how the request from _<http://tcs-webapp.ced-sougang.com>_ is getting permanently redirected to _<https://tcs-webapp.ced-sougang.com>_ with the HTTP response 301

```typescript
C:\Users\tcsougan>curl -I http://webapp.ced-sougang.com
HTTP/1.1 301 Moved Permanently
Server: Microsoft-Azure-Application-Gateway/v2
Date: Mon, 18 Apr 2022 07:02:57 GMT
Content-Type: text/html
Content-Length: 195
Connection: keep-alive
Location: https://webapp.ced-sougang.com/
```

### NSG with your AppGW v2 SKU

Following the public [documentation](https://docs.microsoft.com/en-us/azure/application-gateway/configuration-infrastructure?msclkid=bbfb3521bee111ec8a169d9c0ac3e41c#network-security-groups), beside of the default rules already created, there should be the routes to allow the Gateway Manager for teh Azure infrastructure communication (Probe traffic is included here), then the rules to allow the traffic on the Ports you are planning to expose publicly ( usually 80 and 443). No other outbound rules that deny any outbound connectivity should be created.

- Create the NSG

```typescript
az network nsg create --resource-group "tcs-appgwkv-rg" --name "tcs-appgw-nsg"
```

- Create the rules

```typescript
az network nsg rule create --resource-group "tcs-appgwkv-rg" --nsg-name "tcs-appgw-nsg" --name AppGWv2-GMRules --priority 400 \
                            --source-address-prefixes "*" --source-port-ranges "*" \
                            --destination-address-prefixes '*' --destination-port-ranges "65200-65535" --access "Allow" \
                            --protocol Tcp --description "Allow Azure Infrastructure Communication"

az network nsg rule create --resource-group "tcs-appgwkv-rg" --nsg-name "tcs-appgw-nsg" --name "HTTP-Rule" --priority 200 \
                            --source-address-prefixes "*" --source-port-ranges "*" \
                            --destination-address-prefixes '*' --destination-port-ranges "80" --access "Allow" \
                            --protocol Tcp --description "Allow HTTP Traffic"

az network nsg rule create --resource-group "tcs-appgwkv-rg" --nsg-name "tcs-appgw-nsg" --name "HTTPS-Rule" --priority 180 \
                            --source-address-prefixes "*" --source-port-ranges "*" \
                            --destination-address-prefixes '*' --destination-port-ranges "443" --access "Allow" \
                            --protocol Tcp --description "Allow HTTPS Traffic"
```

- Associate the NSG to the AppGW subnet

```typescript
az network vnet subnet update --name "apps-sbnt" --vnet-name "appgwkv-vnet-01" \ 
                            --resource-group "tcs-appgwkv-rg" \
                            --network-security-group "tcs-appgw-nsg"
```

### Rewrite rules

- Let's set up a rewrite rule to remove the header named "Server" from the Response Header, and apply it on all the webapp rules
- Let's set up a rewrite rule to add the custom header named "EngineerName" to the Response Header, and apply it on all the appgwkv rules
- Use the Developer Tools to verify the rules before and after applying them to the AppGW.

Application Gateway has some quite interesting features. Here, we have chosen to work on a few that our customers struggle the most with. They will be more labs related to AppGw in the future, but in the meantime, I hope you have learned something from this one.
