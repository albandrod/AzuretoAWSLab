# AzuretoAWSLab
With AWS IKEv2 support available the following lab creates Azure Hub-Spoke and connects over S2S VPN using Azure and AWS native Gateways to a AWS VPC. This lab can be used to test connection and routing within both VPC and VNET.

Prereqs:
* Access to Azure Subscription
* Access to AWS Account
* AWS Access Key/Secret
- Terraform Client
- Azure CLI (Used to az login for executing Terraform to provision Azure without storing variable creds)

![Azure to AWS Architecture Image](https://github.com/swiftsolves-msft/AzuretoAWSLab/blob/master/images/Azure2AWS.png "Azure to AWS Architecture Image")
