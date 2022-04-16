# Application Gateway: Keyvault integration, App service integration, End-to-End SSL, few common issues and more

## Introduction

Application Gateway is one of the most popular products offered by Azure. It is very powerful and sometimes can be an essential piece for some applications out there. Configuring and managing some of the features it offers can often be a a huge challenge for customers. In this lab, we'll be experimenting and configuring some of those features like: End-to-End TLS termination, Keyvault integration, App service integration as backend., and also we'll be covering a few of the issues that we are noticing from the customers.

## Prerequisites and architecture

In order to complete this lab, there are quite of resources needed:

- A domain name
- SSL certificate
- A valid Azure subscription
- Terraform
- Git
- Knowing how application gateway works

Different scenarios will be implemented, few tasks and questions will be covered to make sure that we all understand the concept and the configuration. Below is the architecture we'll be working with and it will be changing based on the scenario studied.

![Architecture]()

## Deployment

Keyvault Private endpoint with couple scenarios: Private endpoint and custom-dns server within the same VNET, custom-dns and Private endpoint in two different VNETs.
