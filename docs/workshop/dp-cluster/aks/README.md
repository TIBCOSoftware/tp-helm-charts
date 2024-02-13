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
    * [Ingress Controller](#ingress-controller)
    * [Storage Class](#storage-class)
  * [Install Observability tools](#install-observability-tools)
    * [Install Elastic stack](#install-elastic-stack)
    * [Install Prometheus stack](#install-prometheus-stack)
    * [Install Opentelemetry Collector for metrics](#install-opentelemetry-collector-for-metrics)
  * [Information needed to be set on TIBCO® Control Plane](#information-needed-to-be-set-on-tibco®-control-plane)
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
* kubectl (v1.28.3)
* helm (v3.13.1)

For reference, [Dockerfile](../../Dockerfile) with [apline 3.19](https://hub.docker.com/_/alpine) can be used to build a docker image with all the tools mentioned above, pre-installed.
The subsequent steps can be followed from within the container.

> [!IMPORTANT]
> Please use --platform while building the image with [docker buildx commands](https://docs.docker.com/engine/reference/commandline/buildx_build/).
> This can be different based on your machine OS and hardware architecture.

A sample command on Linux AMD64 is
```bash
docker buildx build --platform=${platform} --progress=plain \
  --build-arg AZURE_CLI_VERSION=${AZURE_CLI_VERSION} \
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
```bash
## Azure specific variables
export DP_SUBSCRIPTION_ID=$(az account show --query id -o tsv) # subscription id
export DP_TENANT_ID=$(az account show --query tenantId -o tsv) # tenant id
export DP_AZURE_REGION="eastus" # region of resource group

## Cluster configuration specific variables
export DP_RESOURCE_GROUP="dp-resource-group" # resource group name
export DP_CLUSTER_NAME="dp-cluster" # name of the cluster to be prvisioned, used for chart deployment
export DP_USER_ASSIGNED_IDENTITY_NAME="${DP_CLUSTER_NAME}-identity" # user assigned identity to be associated with cluster
export KUBECONFIG=`pwd`/${DP_CLUSTER_NAME}.yaml # kubeconfig saved as cluster name yaml

## Network specific variables
export DP_VNET_NAME="${DP_CLUSTER_NAME}-vnet" # name of VNet resource
export DP_VNET_CIDR="10.4.0.0/16" # CIDR of the VNet
export DP_AKS_SUBNET_NAME="aks-subnet" # name of AKS subnet resource
export DP_AKS_SUBNET_CIDR="10.4.0.0/20" # CIDR of the AKS subnet address space
export DP_APPLICATION_GW_SUBNET_NAME="appgw-subnet" # name of application gateway subnet
export DP_APPLICATION_GW_SUBNET_CIDR="10.4.17.0/24" # CIDR of the application gateway subnet address space
export DP_PUBLIC_IP_NAME="public-ip" # name of public ip resource
export DP_NAT_GW_NAME="nat-gateway" # name of NAT gateway resource
export DP_NAT_GW_SUBNET_NAME="natgw-subnet" # name of NAT gateway subnet
export DP_NAT_GW_SUBNET_CIDR="10.4.18.0/27" # CIDR of the NAT gateway subnet address space
export DP_APISERVER_SUBNET_NAME="apiserver-subnet" # name of api server subnet resource
export DP_APISERVER_SUBNET_CIDR="10.4.19.0/28" # CIDR of the kubernetes api server subnet address space
export DP_NODE_VM_SIZE="Standard_D4s_v3" # VM Size of nodes

## By default, only your public IP will be added to allow access to public cluster
export DP_AUTHORIZED_IP=""  # declare additional IPs to be whitelisted for accessing cluster

## Tooling specific variables
export DP_TIBCO_HELM_CHART_REPO=https://tibcosoftware.github.io/tp-helm-charts # location of charts repo url
export DP_DOMAIN="dp1.azure.example.com" # domain to be used
export DP_SANDBOX_SUBDOMAIN="dp1" # hostname of DP_DOMAIN
export DP_TOP_LEVEL_DOMAIN="azure.example.com" # top level domain of DP_DOMAIN
export DP_MAIN_INGRESS_CLASS_NAME="azure-application-gateway" # name of azure application gateway ingress controller
export DP_DISK_ENABLED="true" # to enable azure disk storage class
export DP_DISK_STORAGE_CLASS="azure-disk-sc" # name of azure disk storage class
export DP_FILE_ENABLED="true" # to enable azure files storage class
export DP_FILE_STORAGE_CLASS="azure-files-sc" # name of azure files storage class
export DP_INGRESS_CLASS="nginx" # name of main ingress class used by capabilities 
export DP_ES_RELEASE_NAME="dp-config-es" # name of dp-config-es release name
export DP_DNS_RESOURCE_GROUP="" # replace with name of resource group containing dns record sets
export DP_NETWORK_POLICY="" # possible values "" (to disable network policy), "calico"
export DP_STORAGE_ACCOUNT_NAME="" # replace with name of existing storage account to be used for azure file shares
export DP_STORAGE_ACCOUNT_RESOURCE_GROUP="" # replace with name of storage account resource group
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
> [!NOTE]
> The AKS cluster provisioned is of version 1.28 which is in [public preview mode](https://> azure.microsoft.com/en-us/updates/public-preview-aks-support-for-kubernetes-version-128/)

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
az aks get-credentials --resource-group ${DP_RESOURCE_GROUP} --name ${DP_CLUSTER_NAME} --file "${KUBECONFIG}" --overwrite-existing
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
> in the helm upgrade command i.e. --labels layer=number. Adding labels is supported in helm version v3.13. Label
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
  - ${DP_DOMAIN}
extraVolumes: # for azure.json
- name: azure-config-file
  secret:
    secretName: azure-config-file
extraVolumeMounts:
- name: azure-config-file
  mountPath: /etc/kubernetes
  readOnly: true
extraArgs:
- --ingress-class=${DP_MAIN_INGRESS_CLASS_NAME}
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
For this workshop we will use `dp1.azure.example.com` as the domain name. We will use `*.dp1.azure.example.com` as the wildcard domain name for all the DP capabilities.
We are using the following services in this workshop:
* [DNS Zones](https://learn.microsoft.com/en-us/azure/dns/dns-zones-records): to manage DNS. We register `azure.example.com` in Azure DNS Zones.
* [Let's Encrypt](https://cert-manager.io/docs/configuration/acme/dns01/azuredns/): to manage SSL certificate. We will create a wildcard certificate for `*.dp1.azure.example.com`.
* azure-application-gateway: to create Application Gateway. It will automatically create listeners and add SSL certificate to application gateway.
* external-dns: to create DNS record in dns zone for the record set. It will automatically create DNS record for ingress objects.

### Ingress Controller

```bash
export DP_CLIENT_ID=$(az aks show --resource-group "${DP_RESOURCE_GROUP}" --name "${DP_CLUSTER_NAME}" --query "identityProfile.kubeletidentity.clientId" --output tsv)
## following section is required to send traces using nginx
## uncomment the below commented section to run/re-run the command, once DP_NAMESPACE is available
export DP_NAMESPACE="ns"

helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ingress-system dp-config-aks dp-config-aks \
  --labels layer=1 \
  --repo "${DP_TIBCO_HELM_CHART_REPO}" --version "1.0.16" -f - <<EOF
global:
  dnsSandboxSubdomain: "${DP_SANDBOX_SUBDOMAIN}"
  dnsGlobalTopDomain: "${DP_TOP_LEVEL_DOMAIN}"
  azureSubscriptionDnsResourceGroup: "${DP_DNS_RESOURCE_GROUP}"
  azureSubscriptionId: "${DP_SUBSCRIPTION_ID}"
  azureAwiAsoDnsClientId: "${DP_CLIENT_ID}"
dns:
  domain: "${DP_DOMAIN}"
httpIngress:
  ingressClassName: ${DP_MAIN_INGRESS_CLASS_NAME}
  annotations:
    external-dns.alpha.kubernetes.io/hostname: "*.${DP_DOMAIN}"
ingress-nginx:
  controller:
    config:
      # required by apps swagger
      use-forwarded-headers: "true"
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
    # otlp-collector-host: otel-userapp.${DP_NAMESPACE}.svc
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

> [!IMPORTANT]
> When creating a kubernetes service with type: loadbalancer, in cases where the virtual machine scale set has a network security group on the subnet level, additional inbound security rules may need to be created to the load balancer external IP address to ensure outside connectivity

### Storage Class

```bash
helm upgrade --install --wait --timeout 1h --create-namespace \
  -n storage-system dp-config-aks-storage dp-config-aks \
  --repo "${DP_TIBCO_HELM_CHART_REPO}" \
  --labels layer=1 \
  --version "1.0.16" -f - <<EOF
dns:
  domain: "${DP_DOMAIN}"
httpIngress:
  enabled: false
clusterIssuer:
  create: false
storageClass:
  azuredisk:
    enabled: ${DP_DISK_ENABLED}
    name: ${DP_DISK_STORAGE_CLASS}
    # reclaimPolicy: "Retain" # uncomment for TIBCO Enterprise Message Service™ (EMS) recommended production configuration (default is Delete)
## uncomment following section, if you want to use TIBCO Enterprise Message Service™ (EMS) recommended production configuration
    # parameters:
    #   skuName: Premium_LRS # other values: Premium_ZRS, StandardSSD_LRS (default)
  azurefile:
    enabled: ${DP_FILE_ENABLED}
    name: ${DP_FILE_STORAGE_CLASS}
    # reclaimPolicy: "Retain" # uncomment for TIBCO Enterprise Message Service™ (EMS) recommended production configuration (default is Delete)
## please note: to support nfs protocol the storage account tier should be Premium with kind FileStorage in supported regions: https://learn.microsoft.com/en-us/troubleshoot/azure/azure-storage/files-troubleshoot-linux-nfs?tabs=RHEL#unable-to-create-an-nfs-share
## following section is required if you want to use an existing storage account. Otherwise, a new storage account is created in the same resource group.
    # parameters:
    #   storageAccount: ${DP_STORAGE_ACCOUNT_NAME}
    #   resourceGroup: ${DP_STORAGE_ACCOUNT_RESOURCE_GROUP}
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
helm upgrade --install --wait --timeout 1h --labels layer=1 --create-namespace -n elastic-system eck-operator eck-operator --repo "https://helm.elastic.co" --version "2.9.0"

# install dp-config-es
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n elastic-system ${DP_ES_RELEASE_NAME} dp-config-es \
  --labels layer=2 \
  --repo "${DP_TIBCO_HELM_CHART_REPO}" --version "1.0.17" -f - <<EOF
domain: ${DP_DOMAIN}
es:
  version: "8.9.1"
  ingress:
    ingressClassName: ${DP_INGRESS_CLASS}
    service: ${DP_ES_RELEASE_NAME}-es-http
  storage:
    name: ${DP_DISK_STORAGE_CLASS}
kibana:
  version: "8.9.1"
  ingress:
    ingressClassName: ${DP_INGRESS_CLASS}
    service: ${DP_ES_RELEASE_NAME}-kb-http
apm:
  enabled: true
  version: "8.9.1"
  ingress:
    ingressClassName: ${DP_INGRESS_CLASS}
    service: ${DP_ES_RELEASE_NAME}-apm-http
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
  --repo "https://prometheus-community.github.io/helm-charts" --version "48.3.4" -f <(envsubst '${DP_DOMAIN}, ${DP_INGRESS_CLASS}' <<'EOF'
grafana:
  plugins:
    - grafana-piechart-panel
  ingress:
    enabled: true
    ingressClassName: ${DP_INGRESS_CLASS}
    hosts:
    - grafana.${DP_DOMAIN}
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
    ingressClassName: ${DP_INGRESS_CLASS}
    hosts:
    - prometheus-internal.${DP_DOMAIN}
EOF
)
```
</details>

Use this command to get the host URL for Kibana
```bash
kubectl get ingress -n prometheus-system kube-prometheus-stack-grafana -oyaml | yq eval '.spec.rules[0].host'
```

The username is `admin`. And Prometheus Operator use fixed password: `prom-operator`.

### Install Opentelemetry Collector for metrics

<details>

<summary>Use the following command to install Opentelemetry Collector for metrics</summary>

```bash
## create the values.yaml file with below contents
## make sure the identations are in-tact
mode: "daemonset"
fullnameOverride: otel-kubelet-stats
podLabels:
  platform.tibco.com/workload-type: "infra"
  networking.platform.tibco.com/kubernetes-api: enable
  egress.networking.platform.tibco.com/internet-all: enable
  prometheus.io/scrape: "true"
  prometheus.io/path: "metrics"
  prometheus.io/port: "4319"
autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 10
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 15
    scaleDown:
      stabilizationWindowSeconds: 15
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80
serviceAccount:
  create: true
clusterRole:
  create: true
  rules:
  - apiGroups: [""]
    resources: ["pods", "namespaces"]
    verbs: ["get", "watch", "list"]
  - apiGroups: [""]
    resources: ["nodes/stats", "nodes/proxy"]
    verbs: ["get"]
extraEnvs:
  - name: KUBE_NODE_NAME
    valueFrom:
      fieldRef:
        fieldPath: spec.nodeName
ports:
  metrics:
    enabled: true
    containerPort: 8888
    servicePort: 8888
    hostPort: 8888
    protocol: TCP
  prometheus:
    enabled: true
    containerPort: 4319
    servicePort: 4319
    hostPort: 4319
    protocol: TCP
config:
  receivers:
    kubeletstats/user-app:
      collection_interval: 20s
      auth_type: "serviceAccount"
      endpoint: "https://${env:KUBE_NODE_NAME}:10250"
      insecure_skip_verify: true
      metric_groups:
        - pod
        - container
      extra_metadata_labels:
        - container.id
      metrics:
        k8s.container.memory_limit_utilization:
          enabled: true
        k8s.container.cpu_limit_utilization:
          enabled: true
        k8s.pod.cpu_limit_utilization:
          enabled: true
        k8s.pod.memory_limit_utilization:
          enabled: true
        k8s.pod.filesystem.available:
          enabled: false
        k8s.pod.filesystem.capacity:
          enabled: false
        k8s.pod.filesystem.usage:
          enabled: false
        k8s.pod.memory.major_page_faults:
          enabled: false
        k8s.pod.memory.page_faults:
          enabled: false
        k8s.pod.memory.rss:
          enabled: false
        k8s.pod.memory.working_set:
          enabled: false
  processors:
    memory_limiter:
      check_interval: 5s
      limit_percentage: 80
      spike_limit_percentage: 25
    batch: {}
    k8sattributes/kubeletstats:
      auth_type: "serviceAccount"
      passthrough: false
      extract:
        metadata:
          - k8s.pod.name
          - k8s.pod.uid
          - k8s.namespace.name
        annotations:
          - tag_name: connectors
            key: platform.tibco.com/connectors
            from: pod
        labels:
          - tag_name: app_id
            key: platform.tibco.com/app-id
            from: pod
          - tag_name: app_type
            key: platform.tibco.com/app-type
            from: pod
          - tag_name: dataplane_id
            key: platform.tibco.com/dataplane-id
            from: pod
          - tag_name: workload_type
            key: platform.tibco.com/workload-type
            from: pod
          - tag_name: app_name
            key: platform.tibco.com/app-name
            from: pod
          - tag_name: app_version
            key: platform.tibco.com/app-version
            from: pod
          - tag_name: app_tags
            key: platform.tibco.com/tags
            from: pod
      pod_association:
        - sources:
            - from: resource_attribute
              name: k8s.pod.uid
    filter/user-app:
      metrics:
        include:
          match_type: strict
          resource_attributes:
            - key: workload_type
              value: user-app
    transform/metrics:
      metric_statements:
      - context: datapoint
        statements:
          - set(attributes["pod_name"], resource.attributes["k8s.pod.name"])
          - set(attributes["pod_namespace"], resource.attributes["k8s.namespace.name"])
          - set(attributes["app_id"], resource.attributes["app_id"])
          - set(attributes["app_type"], resource.attributes["app_type"])
          - set(attributes["dataplane_id"], resource.attributes["dataplane_id"])
          - set(attributes["workload_type"], resource.attributes["workload_type"])
          - set(attributes["app_tags"], resource.attributes["app_tags"])
          - set(attributes["app_name"], resource.attributes["app_name"])
          - set(attributes["app_version"], resource.attributes["app_version"])
          - set(attributes["connectors"], resource.attributes["connectors"])
    filter/include:
      metrics:
        include:
          match_type: regexp
          metric_names:
            - .*memory.*
            - .*cpu.*
  exporters:
    prometheus/user:
      endpoint: 0.0.0.0:4319
      enable_open_metrics: true
      resource_to_telemetry_conversion:
        enabled: true
  extensions:
    health_check: {}
    memory_ballast:
      size_in_percentage: 40
  service:
    telemetry:
      logs: {}
      metrics:
        address: :8888
    extensions:
      - health_check
      - memory_ballast
    pipelines:
      logs: null
      traces: null
      metrics:
        receivers:
          - kubeletstats/user-app
        processors:
          - k8sattributes/kubeletstats
          - filter/user-app
          - filter/include
          - transform/metrics
          - batch
        exporters:
          - prometheus/user
```

```bash
## pass the values.yaml file created to the chart upgrade
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n prometheus-system otel-collector-daemon opentelemetry-collector \
  --labels layer=2 \
  --repo "https://open-telemetry.github.io/opentelemetry-helm-charts" --version "0.72.0" -f values.yaml
```
</details>

## Information needed to be set on TIBCO® Control Plane

You can get BASE_FQDN (fully qualified domain name) by running the following command:
```bash
kubectl get ingress -n ingress-system nginx |  awk 'NR==2 { print $3 }'
```

| Name                 | Sample value                                                                     | Notes                                                                     |
|:---------------------|:---------------------------------------------------------------------------------|:--------------------------------------------------------------------------|
| VNET_CIDR             | 10.4.0.0/16                                                                    | from VNet address space                                      |
| Ingress class name   | nginx                                                                            | used for TIBCO BusinessWorks™ Container Edition                                                     |
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
Network Policies Details for Data Plane Namespace | [Data Plane Network Policies Document](https://docs.tibco.com/emp/platform-cp/1.0.0/doc/html/UserGuide/controlling-traffic-with-network-policies.htm) | 

## Clean up

Please delete the Data Plane from TIBCO® Control Plane UI.
Refer to [the steps to delete the Data Plane](https://docs.tibco.com/emp/platform-cp/1.0.0/doc/html/Default.htm#UserGuide/deleting-data-planes.htm?TocPath=Managing%2520Data%2520Planes%257C_____2).

Change the directory to [scripts/aks/](../../scripts/aks/) to proceed with the next steps.
```bash
cd scripts/aks
```

For the tools charts uninstallation, Azure file shares deletion and cluster deletion, we have provided a helper [clean-up](../../scripts/aks/clean-up-data-plane.sh).
```bash
./clean-up-data-plane.sh
```
