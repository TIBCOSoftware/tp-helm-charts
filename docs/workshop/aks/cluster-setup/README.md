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
  * [Install External DNS](#install-external-dns)
  * [Install Cluster Issuer and Create Default Certificate](#install-cluster-issuer-and-create-default-certificate)
    * [Install Cluster Issuer](#install-cluster-issuer)
    * [Create Default Certificate](#create-default-certificate)
  * [Regarding Ingress Controllers and Storage Classes](#regarding-ingress-controllers-and-storage-classes)
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
* envsubst (0.24.1, part of homebrew gettext)
* jq (1.8.0)
* yq (v4.45.4)
* bash (5.2.37)
* az (az-cli/2.74.0)
* kubectl (v1.33.1)
* helm (v3.18.0)

For reference, [Dockerfile](../../Dockerfile) with [alpine 3.22](https://hub.docker.com/_/alpine) can be used to build a docker image with all the tools mentioned above, pre-installed.
All the CLI commands in this workshop can be executed inside the container created using the docker image.

> [!IMPORTANT]
> Please use --platform while building the image with [docker buildx commands](https://docs.docker.com/engine/reference/commandline/buildx_build/).
> This can be different based on your [machine OS and hardware architecture](https://docs.docker.com/build/building/multi-platform/)

Sample command on Linux AMD64 to build the docker image:
```bash
docker buildx build --platform="linux/amd64" --progress=plain -t workshop-cli-tools:latest --load .
```

Sample command to run the container:
```bash
## To start an interactive shell
docker run -it --rm workshop-cli-tools:latest /bin/bash

## Mount your working directory with -v $(pwd):/workspace if you need access to local files inside the container.

## All subsequent commands in this workshop can be run from within this container shell.
```

> [!NOTE]
> Please make sure that once the interactive shell session is terminated, the environment 
> variables need to be exported/set again for executing the next set of commands

## Recommended Roles and Permissions
The steps are run with a Service Principal sign in.
The Service Principal has:
* Contributor role assigned over the scope of subscription used for the workshop
* User Access Administrator role assigned over the scope of subscription used for the workshop
* Microsoft Graph API permission for Directory.Read.All of type Application for the AAD role to propagate

You will need to [create a service principal with these role assignments](https://learn.microsoft.com/en-us/cli/azure/azure-cli-sp-tutorial-1?tabs=bash) with the above roles and permissions.

You can optionally choose to run the steps as an Azure Subscription user with above permissions.

> [!NOTE]
> Please use this user with recommended roles and permissions, to create and access AKS cluster

## Export required variables

Following variables are required to be set to run the scripts and are referred throughout the document.
Please set/adjust the values of the variables as expected.

> [!NOTE]
> We have used the prefix `TP_` for the required variables.
> It stands for "TIBCO PLATFORM".

> [!IMPORTANT]
> We are using AZ CLI commands to create the pre-requisites, create the 
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
export TP_CLUSTER_NAME="tp-cluster" # name of the cluster to be provisioned, used for chart deployment
export TP_KUBERNETES_VERSION="1.33" # please refer: https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions?tabs=azure-cli
export TP_USER_ASSIGNED_IDENTITY_NAME="${TP_CLUSTER_NAME}-identity" # user assigned identity to be associated with cluster
export KUBECONFIG=`pwd`/${TP_CLUSTER_NAME}.yaml # kubeconfig saved as cluster name yaml

## Network specific variables
export TP_VNET_NAME="${TP_CLUSTER_NAME}-vnet" # name of VNet resource
export TP_VNET_CIDR="10.4.0.0/16" # CIDR of the VNet
export TP_SERVICE_CIDR="10.0.0.0/16" # CIDR for service cluster IPs
export TP_SERVICE_DNS_IP="10.0.0.10" # IP address assigned to the Kubernetes DNS service
export TP_AKS_SUBNET_NAME="aks-subnet" # name of AKS subnet resource
export TP_AKS_SUBNET_CIDR="10.4.0.0/20" # CIDR of the AKS subnet address space
export TP_ADDON_ENABLE_APPLICATION_GW="false" # true to enable application gateway ingress controller
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
export TP_DNS_RESOURCE_GROUP="" # resource group used for record-sets
export TP_MAIN_INGRESS_SANDBOX_SUBDOMAIN="department" # subdomain prefix for sandbox
export TP_SANDBOX="dp1" # subdomain prefix for TP_DOMAIN
export TP_TOP_LEVEL_DOMAIN="azure.example.com" # top level domain of TP_DOMAIN
export TP_DOMAIN="${TP_MAIN_INGRESS_SANDBOX_SUBDOMAIN}.${TP_SANDBOX}.${TP_TOP_LEVEL_DOMAIN}" # domain to be used
export TP_INGRESS_CLASS="nginx" # name of main ingress class used by capabilities, use 'traefik'
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
  * Application gateway (if enabled)
  * NAT gateway

Change the directory to [aks/scripts/](../../aks/scripts/) to proceed with the next steps.
```bash
cd aks/scripts
```

> [!IMPORTANT]
> Please make sure that you [export the required variables](#export-required-variables) before executing the script. 

```bash
./pre-aks-cluster-script.sh
```
It will take approximately 5 minutes to complete the configuration.

## Create Azure Kubernetes Service (AKS) cluster

### Enable Preview Features
Enabling preview features is a one-time step and can be done explicitly using the [cli command to register feature](https://learn.microsoft.com/en-us/cli/azure/feature?view=azure-cli-latest#az-feature-register). 
Otherwise, you might get a prompt to allow to register the feature as part of create cluster script execution, if it is not registered already.

Please register the following preview features for the subscription:

EnableAPIServerVnetIntegrationPreview

To ensure that the cluster API server endpoint is available publicly and can be accessed over VNet by node, supports flag --enable-apiserver-vnet-integration

```bash
az feature register --namespace "Microsoft.ContainerService" --name "EnableAPIServerVnetIntegrationPreview"
```

### Add Preview Extension
You will also need to [add the aks-preview extension for API Server VNet integration using cli command](https://learn.microsoft.com/en-us/azure/aks/api-server-vnet-integration)
```bash
az extension add --name aks-preview
```

### Create Cluster Script

Change the directory to [aks/scripts/](../../aks/scripts/) to proceed with the next steps.
```bash
cd aks/scripts
```

> [!IMPORTANT]
> Please make sure that you [export the required variables](#export-required-variables) before executing the script 

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

> [!IMPORTANT]
> Please make sure that you [export the required variables](#export-required-variables) before executing the script 

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

Please use the following commands to install [cert-manager](https://cert-manager.io/docs/installation/helm/) to automatically provision, manage, and renew TLS/SSL certificates

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

## Install External DNS

> [!IMPORTANT]
> We are assuming the customer will be using the Azure DNS Service

Before creating ingress on this AKS cluster, we need to install [external-dns](https://github.com/kubernetes-sigs/external-dns/tree/master/charts/external-dns) to automatically create and update public DNS records in Azure DNS which point to Kubernetes Ingresses and Services

```bash
# install external-dns
helm upgrade --install --wait --timeout 1h --create-namespace  --reuse-values \
  -n external-dns-system external-dns external-dns \
  --labels layer=0 \
  --repo "https://kubernetes-sigs.github.io/external-dns" --version "1.15.2" -f - <<EOF
provider: azure
sources:
  - service
  - ingress
domainFilters:
- ${TP_SANDBOX}.${TP_TOP_LEVEL_DOMAIN} # must be the sandbox domain as we create DNS zone for this
extraVolumes: # for azure.json
- name: azure-config-file
  secret:
    secretName: azure-config-file
extraVolumeMounts:
- name: azure-config-file
  mountPath: /etc/kubernetes
  readOnly: true
extraArgs:
# only register DNS for these ingress classes
- "--ingress-class=${TP_INGRESS_CLASS}"
- --txt-wildcard-replacement=wildcard # issue for Azure dns zone: https://github.com/kubernetes-sigs/external-dns/issues/2922
EOF
```

## Install Cluster Issuer and Create Default Certificate

In this section, we will install cluster issuer. We have made a helm chart called `dp-config-aks` that encapsulates the installation of ingress controller and storage class.
It will create the following resource:
* cluster issuer to represent certificate authorities (CAs) that are able to generate signed certificates by honoring certificate signing requests

We will also create a default certificate for `TP_DOMAIN`.

### Install Cluster Issuer 

```bash
export TP_CLIENT_ID=$(az aks show --resource-group "${TP_RESOURCE_GROUP}" --name "${TP_CLUSTER_NAME}" --query "identityProfile.kubeletidentity.clientId" --output tsv)

helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ingress-system dp-config-aks-ingress-certificate dp-config-aks \
  --labels layer=1 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
global:
  dnsSandboxSubdomain: "${TP_SANDBOX}"
  dnsGlobalTopDomain: "${TP_TOP_LEVEL_DOMAIN}"
  azureSubscriptionDnsResourceGroup: "${TP_DNS_RESOURCE_GROUP}"
  azureSubscriptionId: "${TP_SUBSCRIPTION_ID}"
  azureAwiAsoDnsClientId: "${TP_CLIENT_ID}"
httpIngress:
  enabled: false
  name: main # this is part of cluster issuer name. 
ingress-nginx:
  enabled: false
kong:
  enabled: false
EOF
```

In order to make sure that the network traffic is allowed from the ingress-system namespace to the Control Plane and Data Plane namespace pods, we need to label this namespace.

```bash
# For Control Plane
kubectl label namespace ingress-system networking.platform.tibco.com/non-cp-ns=enable --overwrite=true

# For Data Plane
kubectl label namespace ingress-system networking.platform.tibco.com/non-dp-ns=enable --overwrite=true
```

### Create Default Certificate

The default certificate is mostly used for Data Plane. New certificate/certificates will be required for Control Plane depending on your domains.

Create a certificate using the issuer created [above](#install-cluster-issuer) which can be the default certificate for the ingress controller

```bash
kubectl apply -f - << EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: tp-certificate-main-ingress
  namespace: ingress-system
spec:
  secretName: tp-certificate-main-ingress
  issuerRef:
    name: "cic-cert-subscription-scope-production-main"
    kind: ClusterIssuer
  dnsNames:
    - '*.${TP_DOMAIN}'
EOF
```

## Regarding Ingress Controllers and Storage Classes

Installation of Ingress Controller and Storage Classes is required for deploying Control Plane as well as Data Plane. Common installations of these resources can be leveraged, if you are planning to host both Control Plane and Data Plane in your kubernetes cluster.

We recommend that you go through the sections
[Install Ingress Controller and Storage Class in Control Plane](../control-plane/README.md#install-ingress-controller-storage-classes) and [Install Ingress Controllers and Storage Class in Data Plane](../data-plane/README.md#install-ingress-controllers-storage-classes) to derive and determine the configuration required for your setup.

# Next Steps
For Control Plane, follow the steps from [Control Plane README](../control-plane/README.md)

For Data Plane, follow the steps from [Data Plane README](../data-plane/README.md)
