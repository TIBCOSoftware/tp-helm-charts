Table of Contents
=================
<!-- TOC -->
* [Table of Contents](#table-of-contents)
* [Data Plane Cluster Workshop](#data-plane-cluster-workshop)
  * [Introduction](#introduction)
  * [Command Line Tools required](#command-line-tools-required)
  * [Recommended Roles and Permissions](#recommended-roles-and-permissions)
  * [Export required variables](#export-required-variables)
  * [Pre cluster creation scripts](#pre-cluster-creation-scripts)
  * [Create Azure Kubernetes Service (AKS) cluster](#create-azure-kubernetes-service-aks-cluster)
  * [Post cluster create scripts](#post-cluster-creation-scripts)
  * [Generate kubeconfig to connect to AKS cluster](#generate-kubeconfig-to-connect-to-aks-cluster)
  * [Install common third party tools](#install-common-third-party-tools)
  * [Install Ingress Controller, Storage class](#install-ingress-controller-storage-class)
    * [Setup DNS](#setup-dns)
    * [Nginx Ingress Controller](#install-nginx-ingress-controller)
    * [Traefik Ingress Controller [OPTIONAL]](#install-traefik-ingress-controller-optional)
    * [Kong Ingress Controller [OPTIONAL]](#install-kong-ingress-controller-optional)
    * [Storage Class](#storage-class)
  * [Install Observability tools](#install-observability-tools)
    * [Install Elastic stack](#install-elastic-stack)
    * [Install Prometheus stack](#install-prometheus-stack)
  * [Information needed to be set on TIBCO® Data Plane](#information-needed-to-be-set-on-tibco-data-plane)
  * [Clean up](#clean-up)
<!-- TOC -->

# Data Plane Cluster Workshop

The goal of this workshop is to provide a hands-on experience to deploy a Data Plane cluster in Azure. This is the prerequisite for the Data Plane.

> [!Note]
> This workshop is NOT meant for production deployment.

## Introduction

In order to deploy Data Plane, you need to have a Kubernetes cluster and install the necessary tools. This workshop will guide you to create a Kubernetes cluster in Azure and install the necessary tools.

## Command Line Tools required

The steps mentioned below were run on a Macbook Pro linux/amd64 platform. The following tools are installed using [brew](https://brew.sh/):
* envsubst (part of homebrew gettext)
* yq (v4.35.2)
* jq (1.7)
* bash (5.2.15)
* az (az-cli/2.53.1)
* kubectl (v1.30.2)
* helm (v3.14.2)

For reference, [Dockerfile](../../Dockerfile) with [apline 3.19](https://hub.docker.com/_/alpine) can be used to build a docker image with all the tools mentioned above, pre-installed.
The subsequent steps can be followed from within the container.

> [!IMPORTANT]
> Please use --platform while building the image with [docker buildx commands](https://docs.docker.com/engine/reference/commandline/buildx_build/).
> This can be different based on your machine OS and hardware architecture.

A sample command on Linux AMD64 is
```bash
docker buildx build --platform=${platform} --progress=plain \
  --build-arg AZURE_CLI_VERSION=${AZURE_CLI_VERSION} \
  --build-arg KUBECTL_VERSION=${KUBECTL_VERSION} \
  -t workshop-cli-tools:latest --load .
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
> We have used the prefixes `TP_` and `DP_` for the required variables.
> These prefixes stand for "TIBCO PLATFORM" and "Data Plane" respectively.

```bash
## Azure specific variables
export TP_SUBSCRIPTION_ID=$(az account show --query id -o tsv) # subscription id
export TP_TENANT_ID=$(az account show --query tenantId -o tsv) # tenant id
export TP_AZURE_REGION="eastus" # region of resource group

## Cluster configuration specific variables
export TP_RESOURCE_GROUP="dp-resource-group" # resource group name
export TP_CLUSTER_NAME="dp-cluster" # name of the cluster to be prvisioned, used for chart deployment
export TP_KUBERNETES_VERSION="1.29.4" # please refer: https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions?tabs=azure-cli; use 1.29 or above
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
export TP_NODE_VM_COUNT="3" # Number of VM nodes in the Azure AKS cluster
export TP_NODE_VM_SIZE="Standard_D4s_v3" # VM Size of nodes

## By default, only your public IP will be added to allow access to public cluster
export TP_AUTHORIZED_IP=""  # declare additional IPs to be whitelisted for accessing cluster

## Tooling specific variables
export TP_TIBCO_HELM_CHART_REPO=https://tibcosoftware.github.io/tp-helm-charts # location of charts repo url
## If you want to use same domain for services and user apps
export TP_DOMAIN="dp1.azure.example.com" # domain to be used
## If you want to use different domain for services and user apps [OPTIONAL]
export TP_DOMAIN="services.dp1.azure.example.com" # domain to be used for services and capabilities
export TP_APPS_DOMAIN="apps.dp1.azure.example.com" # optional - apps dns domain if you want to use different IC for services and apps
export TP_SANDBOX_SUBDOMAIN="dp1" # hostname of TP_DOMAIN
export TP_TOP_LEVEL_DOMAIN="azure.example.com" # top level domain of TP_DOMAIN
export TP_MAIN_INGRESS_CLASS_NAME="azure-application-gateway" # name of azure application gateway ingress controller
export TP_DISK_ENABLED="true" # to enable azure disk storage class
export TP_DISK_STORAGE_CLASS="azure-disk-sc" # name of azure disk storage class
export TP_FILE_ENABLED="true" # to enable azure files storage class
export TP_FILE_STORAGE_CLASS="azure-files-sc" # name of azure files storage class
export TP_INGRESS_CLASS="nginx" # name of main ingress class used by capabilities, use 'traefik' for traefik ingress controller
export TP_ES_RELEASE_NAME="dp-config-es" # name of dp-config-es release name
export TP_DNS_RESOURCE_GROUP="" # replace with name of resource group containing dns record sets
export TP_NETWORK_POLICY="" # possible values "" (to disable network policy), "calico"
export TP_STORAGE_ACCOUNT_NAME="" # replace with name of existing storage account to be used for azure file shares
export TP_STORAGE_ACCOUNT_RESOURCE_GROUP="" # replace with name of storage account resource group
```

Change the directory to [scripts/aks/](../../scripts/aks/) to proceed with the next steps.
```bash
cd scripts/aks
```

## Pre cluster creation scripts
Execute the script to create following Azure resources
* Resource group
* User assigned identity
* Role assignment for the user assigned identity
  * as contributor over the scope of subscription
  * as dns zone contributor over the scope of DNS resource group
  * as network contributor over the scope of data plane resource group
* NAT gateway
* Virtual network
* Subnet for
  * AKS cluster
  * Application gateway
  * NAT gateway

```bash
./pre-aks-cluster-script.sh
```
It will take approximately 5 minutes to complete the configuration.

## Create Azure Kubernetes Service (AKS) cluster
> [!IMPORTNANT]
> Please note, we are using the flag --enable-workload-identity in create cluster command.
> This works, if the preview feature EnableWorkloadIdentityPreview is registered for the subscription.
> You might get a prompt to allow to register the feature as part of script execution, if it is not registered already.
> This is one time step and you can also enable explicitly using the [cli command to register feature](https://learn.microsoft.com/en-us/cli/azure/feature?view=azure-cli-latest#az-feature-register)
> e.g. az feature register --namespace Microsoft.ContainerService --name EnableWorkloadIdentityPreview

> [!IMPORTNANT]
> Please note, we are using the flag --enable-apiserver-vnet-integration in create cluster command.
> This is to esnure that the cluster API server endpoint is available publicly and can be accessed over VNet by nodes.
> This works, if the preview feature EnableAPIServerVnetIntegrationPreview is registered for the subscription.
> You might get a prompt to allow to register the feature as part of script execution, if it is not registered already.
> This is one time step and you can also enable explicitly using the [cli command to register feature](https://learn.microsoft.com/en-us/azure/aks/api-server-vnet-integration)
> e.g. az feature register --namespace "Microsoft.ContainerService" --name "EnableAPIServerVnetIntegrationPreview"
> You will also need to [add the aks-preview extension for API Server VNet integration using cli command](https://learn.microsoft.com/en-us/azure/aks/api-server-vnet-integration)
> e.g. az extension add --name aks-preview

Execute the script
```bash
./aks-cluster-create.sh
```

It will take approximately 15 minutes to create an AKS cluster.

## Post cluster creation scripts
Execute the script to
1. create federated workload identity federation
2. create namespace and secret for external dns

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

## Install common third party tools

Before we deploy ingress or observability tools on an empty AKS cluster; we need to install some basic tools.
* [cert-manager](https://cert-manager.io/docs/installation/helm/)
* [external-dns](https://github.com/kubernetes-sigs/external-dns/tree/master/charts/external-dns)

> [!NOTE]
> In the chart installation commands starting in this section & continued in next sections, you will see labels added
> in the helm upgrade command i.e. --labels layer=number. Adding labels is supported in helm version v3.13 and above. Label
> numbers are added to identify the dependency of chart installations, so that uninstallation can be done in reverse
> sequence (starting with charts not labelled first).

<details>

<summary>We can use the following commands to install these tools</summary>

```bash
# install cert-manager
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n cert-manager cert-manager cert-manager \
  --labels layer=0 \
  --repo "https://charts.jetstack.io" --version "v1.12.3" -f - <<EOF
installCRDs: true
podLabels:
  azure.workload.identity/use: "true"
serviceAccount:
  labels:
    azure.workload.identity/use: "true"
EOF

# install external-dns
helm upgrade --install --wait --timeout 1h --reuse-values \
  -n external-dns-system external-dns external-dns \
  --labels layer=0 \
  --repo "https://kubernetes-sigs.github.io/external-dns" --version "1.13.0" -f - <<EOF
provider: azure
sources:
  - service
  - ingress
domainFilters:
  - ${TP_DOMAIN}
extraVolumes: # for azure.json
- name: azure-config-file
  secret:
    secretName: azure-config-file
extraVolumeMounts:
- name: azure-config-file
  mountPath: /etc/kubernetes
  readOnly: true
extraArgs:
- --ingress-class=${TP_MAIN_INGRESS_CLASS_NAME}
EOF

# upgrade external-dns [OPTIONAL]
# if you prefer to use different DNS for Services and User-App endpoints then you need to upgrade external-dns chart by adding the TP_APPS_DOMAIN in the domainFilters section
helm upgrade --install --wait --timeout 1h --reuse-values \
  -n external-dns-system external-dns external-dns \
  --labels layer=0 \
  --repo "https://kubernetes-sigs.github.io/external-dns" --version "^1.0.0" -f - <<EOF
provider: azure
sources:
  - service
  - ingress
domainFilters:
  - ${TP_DOMAIN}
  - ${TP_APPS_DOMAIN}
extraVolumes: # for azure.json
- name: azure-config-file
  secret:
    secretName: azure-config-file
extraVolumeMounts:
- name: azure-config-file
  mountPath: /etc/kubernetes
  readOnly: true
extraArgs:
- --ingress-class=${TP_MAIN_INGRESS_CLASS_NAME}
EOF
```
</details>

<details>

<summary>Sample output of third party helm charts that we have installed in the AKS cluster</summary>

```bash
$ helm ls -A -a
NAME                         	NAMESPACE          	REVISION	UPDATED                                	STATUS  	CHART                                                                APP VERSION
aks-managed-workload-identity	kube-system        	956     	2023-11-03 11:51:09.441169483 +0000 UTC	deployed	workload-identity-addon-0.1.0-575c84365b912ce669b63fe9cb46727096e72c3           
cert-manager                 	cert-manager       	1       	2023-11-03 17:11:50.00057 +0530 IST    	deployed	cert-manager-v1.12.3                                                 v1.12.3    
external-dns                 	external-dns-system	1       	2023-11-03 17:17:00.469065 +0530 IST   	deployed	external-dns-1.13.0                                                  0.13.5        
```
</details>

## Install Ingress Controller, Storage class

Use the following command to get the ingress class name.
```bash
kubectl get ingressclass
NAME                        CONTROLLER                  PARAMETERS   AGE
azure-application-gateway   azure/application-gateway   <none>       19m
```

In this section, we will install ingress controller and storage class. We have made a helm chart called `dp-config-aks` that encapsulates the installation of ingress controller and storage class.
It will create the following resources:
* a main ingress object which will be able to create Azure Application Gateway and act as a main ingress for DP cluster
* annotation for external-dns to create DNS record for the main ingress
* a storage class for Azure Disks
* a storage class for Azure Files

### Setup DNS
## If you want to use same domain for services and user apps
For this workshop we will use `dp1.azure.example.com` as the domain name. We will use `*.dp1.azure.example.com` as the wildcard domain name for all the DP capabilities.
We are using the following services in this workshop:
* [DNS Zones](https://learn.microsoft.com/en-us/azure/dns/dns-zones-records): to manage DNS. We register `azure.example.com` in Azure DNS Zones.
* [Let's Encrypt](https://cert-manager.io/docs/configuration/acme/dns01/azuredns/): to manage SSL certificate. We will create a wildcard certificate for `*.dp1.azure.example.com`.
* azure-application-gateway: to create Application Gateway. It will automatically create listeners and add SSL certificate to application gateway.
* external-dns: to create DNS record in dns zone for the record set. It will automatically create DNS record for ingress objects.

## If you want to use different domain for services and user apps [OPTIONAL]
For this workshop we will use `services.dp1.azure.example.com` as the domain name. We will use `*.services.dp1.azure.example.com` as the wildcard domain name for all the DP servcies and capabilities. For user apps use `*.apps.dp1.azure.example.com` as the wildcard domain name.
* [DNS Zones](https://learn.microsoft.com/en-us/azure/dns/dns-zones-records): to manage DNS. We register `azure.example.com` in Azure DNS Zones.  ###### need to test will azure.example.com will work or not ?
* [Let's Encrypt](https://cert-manager.io/docs/configuration/acme/dns01/azuredns/): to manage SSL certificate. We will create a wildcard certificate for services `*.services.dp1.azure.example.com` and for user apps `*.apps.dp1.azure.example.com`.
* azure-application-gateway: to create Application Gateway. It will automatically create listeners and add SSL certificate to application gateway.
* external-dns: to create DNS record in dns zone for the record set. It will automatically create DNS record for ingress objects (Please udate the external-dns chart by adding the DNS record in domainFilters section).

### Install Nginx Ingress Controller
* This can be used for both Data Plane Services and Apps
* Optionally, Nginx Ingress Controller can be used for Data Plane Services and Kong Ingress Controller for App Endpoints
> [!Note]
> If you want to use Traefik Ingress Controller instead of Nginx, Please skip this and procceed to [Traefik Ingress Controller ](#install-traefik-ingress-controller-optional) Section
```bash
export TP_CLIENT_ID=$(az aks show --resource-group "${TP_RESOURCE_GROUP}" --name "${TP_CLUSTER_NAME}" --query "identityProfile.kubeletidentity.clientId" --output tsv)
## following section is required to send traces using nginx
## uncomment the below commented section to run/re-run the command, once DP_NAMESPACE is available
export DP_NAMESPACE="ns"

helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ingress-system dp-config-aks-nginx dp-config-aks \
  --labels layer=1 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
global:
  dnsSandboxSubdomain: "${TP_SANDBOX_SUBDOMAIN}"
  dnsGlobalTopDomain: "${TP_TOP_LEVEL_DOMAIN}"
  azureSubscriptionDnsResourceGroup: "${TP_DNS_RESOURCE_GROUP}"
  azureSubscriptionId: "${TP_SUBSCRIPTION_ID}"
  azureAwiAsoDnsClientId: "${TP_CLIENT_ID}"
dns:
  domain: "${TP_DOMAIN}"
httpIngress:
  enabled: true
  name: nginx
  backend:
    serviceName: dp-config-aks-nginx-ingress-nginx-controller
  ingressClassName: ${TP_MAIN_INGRESS_CLASS_NAME}
  annotations:
    cert-manager.io/cluster-issuer: "cic-cert-subscription-scope-production-nginx"
    external-dns.alpha.kubernetes.io/hostname: "*.${TP_DOMAIN}"
ingress-nginx:
  enabled: true
  controller:
    config:
      # refer: https://github.com/kubernetes/ingress-nginx/blob/main/docs/user-guide/nginx-configuration/configmap.md to know more about the following configuration options
      # to support passing the incoming X-Forwarded-* headers to upstreams (required by apps swagger)
      use-forwarded-headers: "true"
      # to support large file upload from Control Plane
      proxy-body-size: "150m"
      # to set the size of the buffer used for reading the first part of the response received
      proxy-buffer-size: 16k
## following section is required to send traces using nginx
## uncomment the below commented section to run/re-run the command, once DP_NAMESPACE is available
    # enable-opentelemetry: "true"
    # log-level: debug
    # opentelemetry-config: /etc/nginx/opentelemetry.toml
    # opentelemetry-operation-name: HTTP $request_method $service_name $uri
    # opentelemetry-trust-incoming-span: "true"
    # otel-max-export-batch-size: "512"
    # otel-max-queuesize: "2048"
    # otel-sampler: AlwaysOn
    # otel-sampler-parent-based: "false"
    # otel-sampler-ratio: "1.0"
    # otel-schedule-delay-millis: "5000"
    # otel-service-name: nginx-proxy
    # otlp-collector-host: otel-userapp-traces.${DP_NAMESPACE}.svc
    # otlp-collector-port: "4317"
  # opentelemetry:
    # enabled: true
EOF
```

Use the following command to get the ingress class name.
```bash
$ kubectl get ingressclass
NAME                        CONTROLLER                  PARAMETERS   AGE
azure-application-gateway   azure/application-gateway   <none>       24m
nginx                       k8s.io/ingress-nginx        <none>       2m18s
```

The `nginx` ingress class is the main ingress that DP will use. The `azure-application-gateway` ingress class is used by Azure Application Gateway.

> [!IMPORTANT]
> You will need to provide this ingress class name i.e. nginx to TIBCO® Control Plane when you deploy capability.


### Install Traefik Ingress Controller [OPTIONAL]
* This can be used for both Data Plane Services and Apps
* Optionally, Traefik Ingress Controller can be used for Data Plane Services and Kong Ingress Controller for App Endpoints
```bash
export TP_CLIENT_ID=$(az aks show --resource-group "${TP_RESOURCE_GROUP}" --name "${TP_CLUSTER_NAME}" --query "identityProfile.kubeletidentity.clientId" --output tsv)
## following variable is required to send traces using traefik
## uncomment the below commented section to run/re-run the command, once DP_NAMESPACE is available
export DP_NAMESPACE="ns" # Replace with your Data Plane namespace

helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ingress-system dp-config-aks-traefik dp-config-aks \
  --labels layer=1 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
global:
  dnsSandboxSubdomain: "${TP_SANDBOX_SUBDOMAIN}"
  dnsGlobalTopDomain: "${TP_TOP_LEVEL_DOMAIN}"
  azureSubscriptionDnsResourceGroup: "${TP_DNS_RESOURCE_GROUP}"
  azureSubscriptionId: "${TP_SUBSCRIPTION_ID}"
  azureAwiAsoDnsClientId: "${TP_CLIENT_ID}"
dns:
  domain: "${TP_DOMAIN}"
httpIngress:
  enabled: true
  name: traefik
  backend:
    serviceName: dp-config-aks-traefik
  ingressClassName: ${TP_MAIN_INGRESS_CLASS_NAME}
  annotations:
    cert-manager.io/cluster-issuer: "cic-cert-subscription-scope-production-traefik"
    external-dns.alpha.kubernetes.io/hostname: "*.${TP_DOMAIN}"
traefik:
  enabled: true
  additionalArguments:
    - '--entryPoints.web.forwardedHeaders.insecure' #You can also use trustedIPs instead of insecure to trust the forwarded headers https://doc.traefik.io/traefik/routing/entrypoints/#forwarded-headers
## following section is required to send traces using traefik
## uncomment the below commented section to run/re-run the command, once DP_NAMESPACE is available
#  tracing:
#    otlp:
#      http:
#        endpoint: http://otel-userapp-traces.$\{DP_NAMESPACE\}.svc.cluster.local:4318/v1/traces
#    serviceName: traefik
EOF
```
Use the following command to get the ingress class name.
```bash
$ kubectl get ingressclass
NAME                        CONTROLLER                           PARAMETERS   AGE
azure-application-gateway   azure/application-gateway            <none>       24m
traefik                     traefik.io/ingress-controller        <none>       2m18s
```

The `traefik` ingress class is the main ingress that DP will use. The `azure-application-gateway` ingress class is used by Azure Application Gateway.

> [!IMPORTANT]
> You will need to provide this ingress class name i.e. traefik to TIBCO® Control Plane when you deploy capability.


### Install Kong Ingress Controller [OPTIONAL]
* In this optional step, you can install the Kong Ingress Controller if you want to use it for User App Endpoints
```bash
export TP_CLIENT_ID=$(az aks show --resource-group "${TP_RESOURCE_GROUP}" --name "${TP_CLUSTER_NAME}" --query "identityProfile.kubeletidentity.clientId" --output tsv)

helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ingress-kong dp-config-aks-kong dp-config-aks \
  --labels layer=1 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
global:
  dnsSandboxSubdomain: "${TP_SANDBOX_SUBDOMAIN}"
  dnsGlobalTopDomain: "${TP_TOP_LEVEL_DOMAIN}"
  azureSubscriptionDnsResourceGroup: "${TP_DNS_RESOURCE_GROUP}"
  azureSubscriptionId: "${TP_SUBSCRIPTION_ID}"
  azureAwiAsoDnsClientId: "${TP_CLIENT_ID}"
dns:
  domain: "${TP_APPS_DOMAIN}"
httpIngress:
  enabled: true
  name: kong
  backend:
    serviceName: dp-config-aks-kong-kong-proxy
  ingressClassName: ${TP_MAIN_INGRESS_CLASS_NAME}
  annotations:
    cert-manager.io/cluster-issuer: "cic-cert-subscription-scope-production-kong"
    external-dns.alpha.kubernetes.io/hostname: "*.${TP_APPS_DOMAIN}"
kong:
  enabled: true
## following environment section is required to send traces using kong
## uncomment the below commented section to run/re-run the command
  # env:
  #   tracing_instrumentations: request,all
  #   tracing_sampling_rate: 1
EOF
```

#### Following extra configuration is required to send traces using kong
We need to deploy the below KongClusterPlugin CR configurations for enabling the opentelemetry plugin on a service.
Before applying the KongClusterPlugin, please modify the metadata.name & config.endpoint with the correct DP namespace.
To enable the BWCE app traces, please set ```BW_OTEL_TRACES_ENABLED``` env variable to true.
```bash
kubectl apply -f - <<EOF
apiVersion: configuration.konghq.com/v1
kind: KongClusterPlugin
metadata:
  name: opentelemetry-example
  annotations:
    kubernetes.io/ingress.class: kong
  labels:
    global: "true"
plugin: opentelemetry
config:
  endpoint: "http://otel-userapp-traces.${DP_NAMESPACE}.svc.cluster.local:4318/v1/traces"
  resource_attributes:
    service.name: "kong-dev"          # This service name will get listed as a service name in Jaeger Query UI
  headers:
    X-Auth-Token: secret-token
  header_type: w3c                    # Must be one of: preserve, ignore, b3, b3-single, w3c, jaeger, ot, aws, gcp, datadog
EOF
```

> Please refer the [Kong Documentation](https://docs.konghq.com/hub/kong-inc/opentelemetry/how-to/basic-example/) for more examples.
Use the following command to get the ingress class name.
```bash
$ kubectl get ingressclass
NAME                                    CONTROLLER                      PARAMETER        AGE
azure-application-gateway        azure/application-gateway                 <none>        24m
nginx                            k8s.io/ingress-nginx                      <none>       2m18s
kong                             ingress-controllers.konghq.com/kong       <none>       4m10s
```
The `kong` ingress class is the ingress that DP will be used by user app endpoints.

> [!IMPORTANT]
> When creating a kubernetes service with type: loadbalancer, in cases where the virtual machine scale set has a network security group on the subnet level, additional inbound security rules may need to be created to the load balancer external IP address to ensure outside connectivity

### Storage Class

```bash
helm upgrade --install --wait --timeout 1h --create-namespace \
  -n storage-system dp-config-aks-storage dp-config-aks \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" \
  --labels layer=1 \
  --version "^1.0.0" -f - <<EOF
dns:
  domain: "${TP_DOMAIN}"
clusterIssuer:
  create: false
storageClass:
  azuredisk:
    enabled: ${TP_DISK_ENABLED}
    name: ${TP_DISK_STORAGE_CLASS}
    # reclaimPolicy: "Retain" # uncomment for TIBCO Enterprise Message Service™ (EMS) recommended production configuration (default is Delete)
## uncomment following section, if you want to use TIBCO Enterprise Message Service™ (EMS) recommended production configuration
    # parameters:
    #   skuName: Premium_LRS # other values: Premium_ZRS, StandardSSD_LRS (default)
  azurefile:
    enabled: ${TP_FILE_ENABLED}
    name: ${TP_FILE_STORAGE_CLASS}
    # reclaimPolicy: "Retain" # uncomment for TIBCO Enterprise Message Service™ (EMS) recommended production configuration (default is Delete)
## please note: to support nfs protocol the storage account tier should be Premium with kind FileStorage in supported regions: https://learn.microsoft.com/en-us/troubleshoot/azure/azure-storage/files-troubleshoot-linux-nfs?tabs=RHEL#unable-to-create-an-nfs-share
## following section is required if you want to use an existing storage account. Otherwise, a new storage account is created in the same resource group.
    # parameters:
    #   storageAccount: ${TP_STORAGE_ACCOUNT_NAME}
    #   resourceGroup: ${TP_STORAGE_ACCOUNT_RESOURCE_GROUP}
## uncomment following section, if you want to use TIBCO Enterprise Message Service™ (EMS) recommended production configuration for Azure Files
    #   skuName: Premium_LRS # other values: Premium_ZRS
    #   protocol: nfs
    ## TIBCO Enterprise Message Service™ (EMS) recommended production values for mountOptions
    # mountOptions:
    #   - soft
    #   - timeo=300
    #   - actimeo=1
    #   - retrans=2
    #   - _netdev
ingress-nginx:
  enabled: false
EOF
```
Use the following command to get the storage class name.

```bash
$ kubectl get storageclass
NAME                    PROVISIONER          RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
azure-files-sc          file.csi.azure.com   Delete          WaitForFirstConsumer   true                   2m35s
azurefile               file.csi.azure.com   Delete          Immediate              true                   24m
azurefile-csi           file.csi.azure.com   Delete          Immediate              true                   24m
azurefile-csi-premium   file.csi.azure.com   Delete          Immediate              true                   24m
azurefile-premium       file.csi.azure.com   Delete          Immediate              true                   24m
default (default)       disk.csi.azure.com   Delete          WaitForFirstConsumer   true                   24m
managed                 disk.csi.azure.com   Delete          WaitForFirstConsumer   true                   24m
managed-csi             disk.csi.azure.com   Delete          WaitForFirstConsumer   true                   24m
azure-disk-sc           disk.csi.azure.com   Delete          WaitForFirstConsumer   true                   24m
managed-csi-premium     disk.csi.azure.com   Delete          WaitForFirstConsumer   true                   24m
managed-premium         disk.csi.azure.com   Delete          WaitForFirstConsumer   true                   24m
```

We will be using the following storage classes created with `dp-config-aks` helm chart.
* `azure-disk-sc` is the storage class for Azure Disks. This is used for
  * storage class for data while provisioning TIBCO Enterprise Message Service™ (EMS) capability
  * storage class for data while provisioning TIBCO® Developer Hub capability
* `azure-files-sc` is the storage class for Azure Files. This is used for
  * artifactmanager while provisioning TIBCO BusinessWorks™ Container Edition capability
  * storage class for log while provisioning provision EMS capability
* `default` is the default storage class for AKS. Azure creates it by default and we don't recommend to use it.

> [!IMPORTANT]
> You will need to provide these storage class names to TIBCO® Control Plane when you deploy capability.

## Install Observability tools

### Install Elastic stack

<details>

<summary>Use the following command to install Elastic stack</summary>

```bash
# install eck-operator
helm upgrade --install --wait --timeout 1h --labels layer=1 --create-namespace -n elastic-system eck-operator eck-operator --repo "https://helm.elastic.co" --version "2.16.0"

# install dp-config-es
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n elastic-system ${TP_ES_RELEASE_NAME} dp-config-es \
  --labels layer=2 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "1.2.1" -f - <<EOF
domain: ${TP_DOMAIN}
es:
  version: "8.17.0"
  ingress:
    ingressClassName: ${TP_INGRESS_CLASS}
    service: ${TP_ES_RELEASE_NAME}-es-http
  storage:
    name: ${TP_DISK_STORAGE_CLASS}
kibana:
  version: "8.17.0"
  ingress:
    ingressClassName: ${TP_INGRESS_CLASS}
    service: ${TP_ES_RELEASE_NAME}-kb-http
apm:
  enabled: true
  version: "8.17.0"
  ingress:
    ingressClassName: ${TP_INGRESS_CLASS}
    service: ${TP_ES_RELEASE_NAME}-apm-http
EOF
```
</details>

Use this command to get the host URL for Kibana
```bash
kubectl get ingress -n elastic-system dp-config-es-kibana -oyaml | yq eval '.spec.rules[0].host'
```

The username is normally `elastic`. We can use the following command to get the password.
```bash
kubectl get secret dp-config-es-es-elastic-user -n elastic-system -o jsonpath="{.data.elastic}" | base64 --decode; echo
```

### Install Prometheus stack

<details>

<summary>Use the following command to install Prometheus stack</summary>

```bash
# install prometheus stack
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n prometheus-system kube-prometheus-stack kube-prometheus-stack \
  --labels layer=2 \
  --repo "https://prometheus-community.github.io/helm-charts" --version "48.3.4" -f <(envsubst '${TP_DOMAIN}, ${TP_INGRESS_CLASS}' <<'EOF'
grafana:
  plugins:
    - grafana-piechart-panel
  ingress:
    enabled: true
    ingressClassName: ${TP_INGRESS_CLASS}
    hosts:
    - grafana.${TP_DOMAIN}
prometheus:
  prometheusSpec:
    enableRemoteWriteReceiver: true
    remoteWriteDashboards: true
    additionalScrapeConfigs:
    - job_name: otel-collector
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - action: keep
        regex: "true"
        source_labels:
        - __meta_kubernetes_pod_label_prometheus_io_scrape
      - action: keep
        regex: "infra"
        source_labels:
        - __meta_kubernetes_pod_label_platform_tibco_com_workload_type
      - action: keepequal
        source_labels: [__meta_kubernetes_pod_container_port_number]
        target_label: __meta_kubernetes_pod_label_prometheus_io_port
      - action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        source_labels:
        - __address__
        - __meta_kubernetes_pod_label_prometheus_io_port
        target_label: __address__
      - source_labels: [__meta_kubernetes_pod_label_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
        replacement: /$1
  ingress:
    enabled: true
    ingressClassName: ${TP_INGRESS_CLASS}
    hosts:
    - prometheus-internal.${TP_DOMAIN}
EOF
)
```
</details>

Use this command to get the host URL for Kibana
```bash
kubectl get ingress -n prometheus-system kube-prometheus-stack-grafana -oyaml | yq eval '.spec.rules[0].host'
```

The username is `admin`. And Prometheus Operator use fixed password: `prom-operator`.

## Information needed to be set on TIBCO® Data Plane

You can get BASE_FQDN (fully qualified domain name) by running the following command:
```bash
kubectl get ingress -n ingress-system nginx |  awk 'NR==2 { print $3 }'
```

| Name                 | Sample value                                                                     | Notes                                                                     |
|:---------------------|:---------------------------------------------------------------------------------|:--------------------------------------------------------------------------|
| VNET_CIDR             | 10.4.0.0/16                                                                    | from VNet address space                                      |
| Ingress class name   | nginx                                                                            | used for TIBCO BusinessWorks™ Container Edition                                                     |
| Ingress class name (Optional)   | kong                                                                            | used for User App Endpoints                                                     |
| Azure Files storage class    | azure-files-sc                                                                           | used for TIBCO BusinessWorks™ Container Edition and TIBCO Enterprise Message Service™ (EMS) Azure Files storage                                         |
| Azure Disks storage class    | azure-disk-sc                                                                          | used for TIBCO Enterprise Message Service™ (EMS)                                             |
| BW FQDN              | bwce.\<BASE_FQDN\>                                                               | Capability FQDN |
| Elastic User app logs index   | user-app-1                                                                       | dp-config-es index template (value configured with o11y-data-plane-configuration in TIBCO® Control Plane)                               |
| Elastic Search logs index     | service-1                                                                        | dp-config-es index template (value configured with o11y-data-plane-configuration in TIBCO® Control Plane)                                |
| Elastic Search internal endpoint | https://dp-config-es-es-http.elastic-system.svc.cluster.local:9200               | Elastic Search service                                                |
| Elastic Search public endpoint   | https://elastic.\<BASE_FQDN\>                                                    | Elastic Search ingress                                                |
| Elastic Search password          | xxx                                                                              |               | Elastic Search password in dp-config-es-es-elastic-user secret                                                     |
| Tracing server host  | https://dp-config-es-es-http.elastic-system.svc.cluster.local:9200               | Elastic Search internal endpoint                                         |
| Prometheus service internal endpoint | http://kube-prometheus-stack-prometheus.prometheus-system.svc.cluster.local:9090 | Prometheus service                                        |
| Prometheus public endpoint | https://prometheus-internal.\<BASE_FQDN\>  |  Prometheus ingress host                                        |
| Grafana endpoint  | https://grafana.\<BASE_FQDN\> | Grafana ingress host                                        |
Network Policies Details for Data Plane Namespace | [Data Plane Network Policies Document](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#UserGuide/controlling-traffic-with-network-policies.htm) |

## Clean up

Please delete the Data Plane from TIBCO® Control Plane UI.
Refer to [the steps to delete the Data Plane](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#UserGuide/deleting-data-planes.htm).

Change the directory to [scripts/aks/](../../scripts/aks/) to proceed with the next steps.
```bash
cd scripts/aks
```

For the tools charts uninstallation, Azure file shares deletion and cluster deletion, we have provided a helper [clean-up](../../scripts/aks/clean-up-data-plane.sh).
```bash
./clean-up-data-plane.sh
```
