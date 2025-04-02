Table of Contents
=================
<!-- TOC -->
* [Table of Contents](#table-of-contents)
* [Azure Kubernetes Service Cluster Creation](#azure-kubernetes-service-cluster-creation)
  * [Introduction](#introduction)
  * [Command Line Tools required](#command-line-tools-required)
  * [Recommended Roles and Permissions](#recommended-roles-and-permissions)
  * [Export required variables](#export-required-variables)
  * [Pre cluster creation scripts](#pre-cluster-creation-scripts)
  * [Create Azure Kubernetes Service (AKS) cluster](#create-azure-kubernetes-service-aks-cluster)
    * [Enable Preview Features](#enable-preview-features)
    * [Add Preview Extension](#add-preview-extension)
    * [Create Cluster Script](#create-cluster-script)
  * [Post Cluster Create Scripts](#post-cluster-creation-scripts)
  * [Generate kubeconfig to connect to AKS cluster](#generate-kubeconfig-to-connect-to-aks-cluster)
* [Install Third Party Tools](#install-third-party-tools)
  * [Install Cert Manager](#install-cert-manager)
* [Next Steps](#next-steps)
<!-- TOC -->

# Azure Kubernetes Service Cluster Creation

The goal of this document is to provide hands-on experience to create Microsoft Azure Kubernetes Service (AKS) cluster with necessary plugins. This is a pre-requisite to deploy TIBCO® Control Plane and/or Data Plane.

> [!Note]
> This workshop is NOT meant for production deployment.

## Introduction

In order to deploy TIBCO® Control Plane and/or Data Plane, you need to have a Kubernetes cluster and install the necessary tools. This workshop will guide you to create a Kubernetes cluster in Azure and install the necessary tools. After completing the steps from this document, you will need to follow separate steps for [TIBCO® Control Plane](../control-plane/) or [Data Plane](../data-plane/) setups.

## Command Line Tools required

The steps mentioned below were run on a Macbook Pro linux/amd64 platform. The following tools are installed using [brew](https://brew.sh/):
* envsubst (0.22.5, part of homebrew gettext)
* jq (1.7.1)
* yq (v4.44.1)
* bash (5.2.26)
* az (az-cli/2.70.0)
* kubectl (v1.31.5)
* helm (v3.14.3)

For reference, [Dockerfile](../../Dockerfile) with [apline 3.20](https://hub.docker.com/_/alpine) can be used to build a docker image with all the tools mentioned above, pre-installed.
The subsequent steps can be followed from within the container.

> [!IMPORTANT]
> Please use --platform while building the image with [docker buildx commands](https://docs.docker.com/engine/reference/commandline/buildx_build/).
> This can be different based on your [machine OS and hardware architecture](https://docs.docker.com/build/building/multi-platform/)

A sample command on Linux AMD64 is
```bash
docker buildx build --platform="linux/amd64" --progress=plain -t workshop-cli-tools:latest --load .
```
## Recommended Roles and Permissions
The steps are run with a Service Principal sign in.
The Service Principal has:
* Contributor role assigned over the scope of subscription used for the workshop
* User Access Administrator role assigned over the scope of subscription used for the workshop
* Microsoft Graph API permission for Directory.Read.All of type Application for the AAD role to propagate

You will need to [create a service principal with these role assignments](https://learn.microsoft.com/en-us/cli/azure/azure-cli-sp-tutorial-1?tabs=bash) with the above roles and permissions.

You can optionally choose run the steps as a Azure Subscription user with above permissions.

> [!NOTE]
> Please use this user with recommended roles and permissions, to create and access AKS cluster

## Export required variables

Following variables are required to be set to run the scripts and are referred throughout the document.
Please set/adjust the values of the variables as expected.

> [!NOTE]
> We have used the prefix `TP_` for the required variables.
> It stands for "TIBCO PLATFORM".

> [!IMPORTANT]
> We are using AZ CLI commands to to create the pre-requisistes, create the 
> cluster and later perform some post script.
> We recommend that you go through the parameters [here](https://learn.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-create(aks-preview))
> so that it will be easier for you to set the values for the variables below.


```bash
## Azure specific variables
export TP_SUBSCRIPTION_ID=$(az account show --query id -o tsv) # subscription id
export TP_TENANT_ID=$(az account show --query tenantId -o tsv) # tenant id
export TP_AZURE_REGION="eastus" # region of resource group

## Cluster configuration specific variables
export TP_RESOURCE_GROUP="" # set the resource group name in which all resources will be deployed
export TP_CLUSTER_NAME="tp-cluster" # name of the cluster to be prvisioned, used for chart deployment
export TP_KUBERNETES_VERSION="1.31.5" # please refer: https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions?tabs=azure-cli
export TP_USER_ASSIGNED_IDENTITY_NAME="${TP_CLUSTER_NAME}-identity" # user assigned identity to be associated with cluster
export KUBECONFIG=`pwd`/${TP_CLUSTER_NAME}.yaml # kubeconfig saved as cluster name yaml

## Network specific variables
export TP_VNET_NAME="${TP_CLUSTER_NAME}-vnet" # name of VNet resource
export TP_VNET_CIDR="10.4.0.0/16" # CIDR of the VNet
export TP_SERVICE_CIDR="10.0.0.0/16" # CIDR for service cluster IPs
export TP_SERVICE_DNS_IP="10.0.0.10" # IP address assigned to the Kubernetes DNS service
export TP_AKS_SUBNET_NAME="aks-subnet" # name of AKS subnet resource
export TP_AKS_SUBNET_CIDR="10.4.0.0/20" # CIDR of the AKS subnet address space
export TP_APPLICATION_GW_SUBNET_NAME="appgw-subnet" # name of application gateway subnet
export TP_APPLICATION_GW_SUBNET_CIDR="10.4.17.0/24" # CIDR of the application gateway subnet address space
export TP_PUBLIC_IP_NAME="public-ip" # name of public ip resource
export TP_NAT_GW_NAME="nat-gateway" # name of NAT gateway resource
export TP_NAT_GW_SUBNET_NAME="natgw-subnet" # name of NAT gateway subnet
export TP_NAT_GW_SUBNET_CIDR="10.4.18.0/27" # CIDR of the NAT gateway subnet address space
export TP_APISERVER_SUBNET_NAME="apiserver-subnet" # name of api server subnet resource
export TP_APISERVER_SUBNET_CIDR="10.4.19.0/28" # CIDR of the kubernetes api server subnet address space
export TP_NODE_VM_COUNT="6" # Number of VM nodes in the Azure AKS cluster
export TP_NODE_VM_SIZE="Standard_D4s_v3" # VM Size of nodes

## Network policy specific variables
export TP_NETWORK_POLICY="azure" # possible values "azure", "calico", "none"
export TP_NETWORK_PLUGIN="azure" # possible values "azure", "calico", "none"

## By default, only your public IP will be added to allow access to public cluster
export TP_AUTHORIZED_IP=""  # declare additional IPs to be whitelisted for accessing cluster

## Helm chart repo
export TP_TIBCO_HELM_CHART_REPO=https://tibcosoftware.github.io/tp-helm-charts # location of charts repo url

## Domain specific 
export TP_TOP_LEVEL_DOMAIN="azure.example.com" # top level domain of TP_DOMAIN
export TP_SANDBOX="dp1" # hostname of TP_DOMAIN
export TP_DOMAIN="${TP_SANDBOX}.${TP_TOP_LEVEL_DOMAIN}" # domain to be used
## If you want to use different domain for services and user apps [OPTIONAL]
export TP_DOMAIN="services.dp1.azure.example.com" # domain to be used for services and capabilities
export TP_APPS_DOMAIN="apps.dp1.azure.example.com" # optional - apps dns domain if you want to use different IC for services and apps
export TP_MAIN_INGRESS_CLASS_NAME="azure-application-gateway" # name of azure application gateway ingress controller
export TP_DNS_RESOURCE_GROUP="" # resource group to be used for record-sets 
```

> [!IMPORTANT]
> The document uses Azure DNS Service for DNS hosting, resolution. 

## Pre Cluster Creation Scripts

pre-aks-cluster-script will create following Azure resources
* Resource group
* User assigned identity
* Role assignment for the user assigned identity
  * as contributor over the scope of subscription
  * as dns zone contributor over the scope of DNS resource group
  * as network contributor over the scope of control plane resource group
* NAT gateway
* Virtual network
* Subnets for
  * AKS cluster nodegroups
  * AKS cluster API Server
  * Application gateway
  * NAT gateway

Change the directory to [aks/scripts/](../../aks/scripts/) to proceed with the next steps.
```bash
cd aks/scripts
```

> [!IMPORTNANT]
> Please make sure that you [export the required vriables](#export-required-variables) before executing the script. 

```bash
./pre-aks-cluster-script.sh
```
It will take approximately 5 minutes to complete the configuration.

## Create Azure Kubernetes Service (AKS) cluster

### Enable Preview Features
Enabling preview features is one time step and can be explicitly using the [cli command to register feature](https://learn.microsoft.com/en-us/cli/azure/feature?view=azure-cli-latest#az-feature-register). 
Otherwise, you might get a prompt to allow to register the feature as part of create cluster script execution, if it is not registered already.

Please register the following preview features for the subscription:
1. EnableAPIServerVnetIntegrationPreview
<br>
To ensure that the cluster API server endpoint is available publicly and can be accessed over VNet by node, supports flag --enable-apiserver-vnet-integration
</br>

```bash
az feature register --namespace "Microsoft.ContainerService" --name "EnableAPIServerVnetIntegrationPreview"
```

### Add Preview Extension
You will also need to [add the aks-preview extension for API Server VNet integration using cli command](https://learn.microsoft.com/en-us/azure/aks/api-server-vnet-integration)
```bash
az extension add --name aks-preview
```

s### Create Cluster Script

Change the directory to [aks/scripts/](../../aks/scripts/) to proceed with the next steps.
```bash
cd aks/scripts
```

> [!IMPORTNANT]
> Please make sure that you [export the required vriables](#export-required-variables) before executing the script 

Execute the script
```bash
./aks-cluster-create.sh
```

It will take approximately 15 minutes to create an AKS cluster.

## Post Cluster Creation Scripts
post-aks-cluster-script will create
1. federated workload identity federation
2. namespace and secret for external dns

Change the directory to [aks/scripts/](../../aks/scripts/) to proceed with the next steps.
```bash
cd aks/scripts
```

> [!IMPORTNANT]
> Please make sure that you [export the required vriables](#export-required-variables) before executing the script 

```bash
./post-aks-cluster-script.sh
```

It will take approximately 5 minutes to complete the configuration.

## Generate kubeconfig to connect to AKS cluster
We can use the following command to generate kubeconfig file.
```bash
az aks get-credentials --resource-group ${TP_RESOURCE_GROUP} --name ${TP_CLUSTER_NAME} --file "${KUBECONFIG}" --overwrite-existing
```

And check the connection to AKS cluster.
```bash
kubectl get nodes
```

# Install Third Party Tools

Before we deploy ingress or observability tools on an empty AKS cluster; we need to install some basic tools.

> [!NOTE]
> In the chart installation commands starting in this section & continued in next sections, you will see labels added
> in the helm upgrade command i.e. --labels layer=\<number\>. Adding labels is supported in helm version v3.13 and above. Label
> numbers are added to identify the dependency of chart installations, so that uninstallation can be done in reverse
> sequence (starting with charts not labelled first).

## Install Cert Manager

Please use the following commands to install [cert-manager](https://cert-manager.io/docs/installation/helm/)

```bash
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n cert-manager cert-manager cert-manager \
  --labels layer=0 \
  --repo "https://charts.jetstack.io" --version "v1.17.1" -f - <<EOF
installCRDs: true
podLabels:
  azure.workload.identity/use: "true"
serviceAccount:
  labels:
    azure.workload.identity/use: "true"
EOF
```

# Next Steps
For Control Plane, follow the steps from [Control Plane README](../control-plane/README.md)

For Data Plane, follow the steps from [Data Plane README](../data-plane/README.md)


