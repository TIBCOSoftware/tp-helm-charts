Table of Contents
=================
<!-- TOC -->
* [Table of Contents](#table-of-contents)
* [TIBCO® Control Plane Cluster Workshop](#tibco-control-plane-aks-workshop)
  * [Export required variables](#export-required-variables)
  * [Install Ingress Controller, Storage classes](#install-ingress-controller-storage-classes)
    * [Install Ingress Controller](#install-ingress-controller)
      * [Install Nginx Ingress Controller](#install-nginx-ingress-controller)
      * [Install Traefik Ingress Controller](#install-traefik-ingress-controller)
      * [Verify Ingress Class Creation](#verify-ingress-class-creation)
    * [Install Storage Classes](#install-storage-classes)
  * [Install Postgres](#install-postgres)
* [TIBCO® Control Plane Deployment](#tibco-control-plane-deployment)
  * [Pre-requisites to create namespace and service account](#pre-requisites-to-create-namespace-and-service-account)
  * [Configure DNS records, Certificates](#configure-dns-records-certificates)
  * [Information needed to be set on TIBCO® Control Plane](#information-needed-to-be-set-on-tibco-control-plane)
  * [Export additional variables required for chart values](#export-additional-variables-required-for-chart-values)
  * [Create prerequisite secrets](#create-prerequisite-secrets)
    * [Generate and Create session-keys Secret (Required)](#generate-and-create-session-keys-secret-required)
    * [Generate and Create cporch-encryption-secret (Required)](#generate-and-create-cporch-encryption-secret-required)
  * [tibco-cp-base Chart values](#tibco-cp-base-chart-values)
  * [Next Steps](#next-steps)
* [Clean-up](#clean-up)
<!-- TOC -->

# TIBCO® Control Plane AKS Workshop

The goal of this workshop is to provide hands-on experience to prepare a Microsoft Azure Kubernetes Service cluster to be used as a TIBCO® Control Plane. In order to deploy TIBCO Control Plane, you need to have a Kubernetes cluster with some necessary tools installed. This workshop will guide you to install the necessary tools.

> [!IMPORTANT]
> This workshop is NOT meant for production deployment.

To perform the steps mentioned in this workshop document, it is assumed you already have an AKS cluster created and can connect to it.

> [!Note]
> To create an AKS cluster and connect to it using kubeconfig, please refer 
> [steps for AKS cluster creation](../cluster-setup/README.md#azure-kubernetes-service-cluster-creation)


## Export required variables

Following variables are required to be set to run the scripts and are referred throughout the document.
Please set/adjust the values of the variables as expected.

> [!NOTE]
> We have used the prefixes `TP_` and `CP_` for the required variables.
> These prefixes stand for "TIBCO PLATFORM" and "Control Plane" respectively.

```bash
## Azure specific variables
export TP_SUBSCRIPTION_ID=$(az account show --query id -o tsv) # subscription id
export TP_TENANT_ID=$(az account show --query tenantId -o tsv) # tenant id
export TP_AZURE_REGION="eastus" # region of resource group

## Cluster configuration specific variables
export TP_RESOURCE_GROUP="" # set the resource group name in which all resources will be deployed
export TP_CLUSTER_NAME="tp-cluster" # name of the cluster to be provisioned, used for chart deployment
export KUBECONFIG=`pwd`/${TP_CLUSTER_NAME}.yaml # kubeconfig saved as cluster name yaml

## Network specific variables
export TP_VNET_CIDR="10.4.0.0/16" # CIDR of the VNet
export TP_SERVICE_CIDR="10.0.0.0/16" # CIDR for service cluster IPs

## Helm chart repo
export TP_TIBCO_HELM_CHART_REPO=https://tibcosoftware.github.io/tp-helm-charts # location of charts repo url

## Domain specific variables
export TP_TOP_LEVEL_DOMAIN="azure.example.com" # top level domain of TP_DOMAIN
export TP_SANDBOX="dp1" # subdomain prefix for TP_DOMAIN
export TP_MAIN_INGRESS_SANDBOX_SUBDOMAIN="department" # sandbox subdomain to be used
export TP_DOMAIN="${TP_MAIN_INGRESS_SANDBOX_SUBDOMAIN}.${TP_SANDBOX}.${TP_TOP_LEVEL_DOMAIN}" # domain to be used
export TP_INGRESS_CLASS="nginx" # name of main ingress class used by capabilities, use 'traefik'
export TP_DNS_RESOURCE_GROUP="" # resource group to be used for record-sets

# Storage specific variables
export TP_DISK_ENABLED="true" # to enable azure disk storage class
export TP_DISK_STORAGE_CLASS="azure-disk-sc" # name of azure disk storage class
export TP_FILE_ENABLED="true" # to enable azure files storage class
export TP_FILE_STORAGE_CLASS="azure-files-sc" # name of azure files storage class

# Network policy specific variables
export TP_ENABLE_NETWORK_POLICY="true" # possible values "true", "false"

# LogServer specific variables
export TP_LOGSERVER_ENDPOINT=""
export TP_LOGSERVER_INDEX="" # logserver index to push the logs to
export TP_LOGSERVER_USERNAME=""
export TP_LOGSERVER_PASSWORD=""
```

## Install Ingress Controller, Storage classes

In this section, we will install ingress controller and storage class. We have made a helm chart called `dp-config-aks` that encapsulates the installation of ingress controller and storage class.
It will create the following resources:
* ingress object which will be able to create Azure load balancer
* annotation for external-dns to create DNS record for the ingress
* storage class for Azure Disks
* storage class for Azure Files

> [!NOTE]
> In the chart installation commands starting in this section & continued in next sections, you will see labels added
> in the helm upgrade command i.e. --labels layer=number. Adding labels is supported in helm version v3.13 and above. Label
> numbers are added to identify the dependency of chart installations, so that uninstallation can be done in reverse
> sequence (starting with charts not labelled first).

### Install Ingress Controller

You can choose to install Nginx or Traefik as the ingress controller for routing traffic to Control Plane services using Azure load balancer.


> [!IMPORTANT]
> If you know the DNS domains for Control Plane in advance, rather than creating certificates for the domain 
> *.${TP_DOMAIN}, you can choose to create the certificates for Control Plane `my` and `tunnel` domains.
> You can use the same certificate for ingress controller as default certificate.
> Follow the steps [Pre-requisites to create namespace and service account](#pre-requisites-to-create-namespace-and-service-account) and then [Configure DNS records, Certificates](#configure-dns-records-certificates).
> Once the certificates are created, please follow with the steps to [Install Nginx Ingress Controller](#install-nginx-ingress-controller)

#### Install Nginx Ingress Controller

The following deployment of Nginx ingress controller creates Azure load balancer.

```bash
helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ingress-system dp-config-aks-ingress dp-config-aks \
  --labels layer=1 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
clusterIssuer:
  create: false
httpIngress:
  enabled: false
ingress-nginx:
  enabled: true
  controller:
    service:
      type: LoadBalancer
      annotations:
        external-dns.alpha.kubernetes.io/hostname: "*.${TP_DOMAIN}"
        service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /healthz
      enableHttp: false # disable http 80 port on service and load balancer
    config:
      # refer: https://github.com/kubernetes/ingress-nginx/blob/main/docs/user-guide/nginx-configuration/configmap.md to know more about the following configuration options
      # to support passing the incoming X-Forwarded-* headers to upstreams
      use-forwarded-headers: "true"
      # to support large file upload from Control Plane
      proxy-body-size: "150m"
      # to set the size of the buffer used for reading the first part of the response received
      proxy-buffer-size: 16k
    extraArgs:
      # set the certificate you have created in ingress-system or Control Plane namespace
      default-ssl-certificate: ingress-system/tp-certificate-main-ingress
EOF
```

#### Install Traefik Ingress Controller

The following deployment of Traefik ingress controller creates Azure load balancer.

```bash
helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ingress-system dp-config-aks-ingress dp-config-aks \
  --labels layer=1 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
clusterIssuer:
  create: false
httpIngress:
  enabled: false
traefik:
  enabled: true
  service:
    type: LoadBalancer
    annotations:
      external-dns.alpha.kubernetes.io/hostname: "*.${TP_DOMAIN}"
      service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /healthz
  ingressRoute: # for dashboard
    dashboard:
      enabled: true
      matchRule: Host(`traefik-alb-apps.${TP_DOMAIN}`) && PathPrefix(`/dashboard`) || Host(`traefik-alb-apps.${TP_DOMAIN}`) && PathPrefix(`/api`)
      entryPoints:
        - traefik
        - web
        - websecure
  providers:  # for external service
    kubernetesIngress:
      allowExternalNameServices: true
  additionalArguments:
    - '--entryPoints.websecure.forwardedHeaders.insecure' # you can also use trustedIPs instead of insecure to trust the forwarded headers https://doc.traefik.io/traefik/routing/entrypoints/#forwarded-headers
    - '--serversTransport.insecureSkipVerify=true' # please refer https://doc.traefik.io/traefik/routing/overview/#transport-configuration
    - '--providers.kubernetesingress.ingressendpoint.publishedservice=ingress-system/dp-config-aks-ingress-traefik'
  tlsStore:
    default:
      defaultCertificate:
        # set the certificate you have created in ingress-system or Control Plane namespace
        secretName: tp-certificate-main-ingress
EOF
```

#### Verify Ingress Class Creation

Use the following command to get the ingress class names.
```bash
$ kubectl get ingressclass
NAME                                    CONTROLLER                      PARAMETER        AGE
nginx                            k8s.io/ingress-nginx                      <none>       2m18s
```

> [!IMPORTANT]
> When creating a kubernetes service with type: loadbalancer, in cases where the virtual machine scale set has a network security group on the subnet level, additional inbound security rules may need to be created to the load balancer external IP address to ensure outside connectivity

### Install Storage Classes

```bash
helm upgrade --install --wait --timeout 1h --create-namespace \
  -n storage-system dp-config-aks-storage dp-config-aks \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" \
  --labels layer=1 \
  --version "^1.0.0" -f - <<EOF
httpIngress:
  enabled: false
clusterIssuer:
  create: false
storageClass:
  azuredisk:
    enabled: ${TP_DISK_ENABLED}
    name: ${TP_DISK_STORAGE_CLASS}
    volumeBindingMode: Immediate
    reclaimPolicy: "Delete"
    parameters:
      skuName: Premium_LRS # other values: Premium_ZRS, StandardSSD_LRS (default)
  azurefile:
    enabled: ${TP_FILE_ENABLED}
    name: ${TP_FILE_STORAGE_CLASS}
    volumeBindingMode: Immediate
    reclaimPolicy: "Delete"
    parameters:
      allowBlobPublicAccess: "false"
      networkEndpointType: privateEndpoint
      skuName: Premium_LRS # other values: Premium_ZRS
    mountOptions:
      - mfsymlinks
      - cache=strict
      - nosharesock
ingress-nginx:
  enabled: false
EOF
```

#### Verify Storage Classes Creation

Use the following command to get the storage class names.

```bash
$ kubectl get storageclass
NAME                    PROVISIONER          RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
azure-files-sc          file.csi.azure.com   Delete          Immediate              true                   24m
azure-disk-sc           disk.csi.azure.com   Delete          Immediate              true                   24m
```

## Install Postgres

In this section, we will install postgres server chart. We have made a helm chart called `on-premises-third-party` that encapsulates the installation of postgres server.

You can optionally use any pre-existing postgres instaltion, but please make sure that the Control Plane pods can communicate with that database.

```bash
export TP_CONTAINER_REGISTRY_URL="csgprduswrepoedge.jfrog.io" # jfrog edge node url us-west-2 region, replace with container registry url as per your deployment region
export TP_CONTAINER_REGISTRY_USER="" # replace with your container registry username
export TP_CONTAINER_REGISTRY_PASSWORD="" # replace with your container registry password
export TP_CONTAINER_REGISTRY_REPOSITORY="tibco-platform-docker-prod" # replace with your container registry repository

helm upgrade --install --wait --timeout 1h --create-namespace \
  -n tibco-ext postgresql on-premises-third-party \
  --labels layer=2 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
global:
  tibco:
    containerRegistry:
      url: "${TP_CONTAINER_REGISTRY_URL}"
      username: "${TP_CONTAINER_REGISTRY_USER}"
      password: "${TP_CONTAINER_REGISTRY_PASSWORD}"
      repository: "${TP_CONTAINER_REGISTRY_REPOSITORY}"
  storageClass: ${TP_DISK_STORAGE_CLASS}
postgresql:
  enabled: true
  auth:
    postgresPassword: postgres
    username: postgres
    password: postgres
    database: "postgres"
  image:
    registry: "${TP_CONTAINER_REGISTRY_URL}"
    repository: ${TP_CONTAINER_REGISTRY_REPOSITORY}/common-postgresql
    tag: 16.4.0-debian-12-r14
    pullSecrets:
    - tibco-container-registry-credentials
    debug: true
  primary:
    # resourcesPreset: "nano" # nano micro small
    resources:
      requests:
        cpu: 250m
        memory: 256Mi
EOF
```

In order to make sure that the network traffic is allowed from the tibco-ext namespace to the Control Plane namespace pods,
we need to label this namespace.
```bash
kubectl label namespace tibco-ext networking.platform.tibco.com/non-cp-ns=enable --overwrite=true
```

> [!IMPORTANT]
> Please note that the postgres installed above does not enforce SSL, by default. It has to be manually configured.
> To enforce SSL while to connecting to the instance, please configure the tls values for the above chart

# TIBCO® Control Plane Deployment

## Pre-requisites to create namespace and service account

We will be creating a namespace the TIBCO Control Plane charts are to be deployed.

```bash

export CP_INSTANCE_ID="cp1" # unique id to identify multiple cp installation in same cluster (alphanumeric string of max 5 chars)

kubectl apply -f <(envsubst '${CP_INSTANCE_ID}' <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
 name: ${CP_INSTANCE_ID}-ns
 labels:
  platform.tibco.com/controlplane-instance-id: ${CP_INSTANCE_ID}
EOF
)
```

Create a service account in the namespace. This service account is used for TIBCO Control Plane deployment.

```bash
kubectl create serviceaccount ${CP_INSTANCE_ID}-sa -n ${CP_INSTANCE_ID}-ns
```

## Configure DNS records, Certificates

We recommend that you use different DNS records and certificates for `my` (control plane application) and `tunnel` (hybrid connectivity) domains. You can use wildcard domain names for these control plane application and hybrid connecivity domains.

We recommend that you use different `CP_INSTANCE_ID` to distinguish multiple control plane installations within a cluster.

Please export below variables and values related to domains:
```bash
## Domains
export CP_INSTANCE_ID="cp1" # unique id to identify multiple cp installation in same cluster (alphanumeric string of max 5 chars)
export CP_MY_DNS_DOMAIN=${CP_INSTANCE_ID}-my.${TP_DOMAIN} # domain to be used
export CP_TUNNEL_DNS_DOMAIN=${CP_INSTANCE_ID}-tunnel.${TP_DOMAIN} # domain to be used
```
`TP_DOMAIN` is exported as part of [Export required variables](#export-required-variables)

In order to make sure that the network traffic is allowed from the ingress-system namespace to the Control Plane namespace pods, we need to label this namespace.
```bash
kubectl label namespace ingress-system networking.platform.tibco.com/non-cp-ns=enable --overwrite=true
```

Create a certificate for the ingress controller using the issuer created earlier in the step [Install Cluster Issuer](#install-cluster-issuer)

```bash
kubectl apply -f - << EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: tp-certificate-${CP_INSTANCE_ID}
  namespace: ${CP_INSTANCE_ID}-ns
spec:
  dnsNames:
  - '*.${CP_MY_DNS_DOMAIN}'
  - '*.${CP_TUNNEL_DNS_DOMAIN}'
  issuerRef:
    kind: ClusterIssuer
    name: cic-cert-subscription-scope-production-main
  secretName: tp-certificate-${CP_INSTANCE_ID}
```

## Information needed to be set on TIBCO® Control Plane

| Name                 | Sample value                                                                     | Notes                                                                     |
|:---------------------|:---------------------------------------------------------------------------------|:--------------------------------------------------------------------------|
| VNET_CIDR             | 10.4.0.0/16                                                                 | Virtual network CIDR from AKS cluster configuration |
| Ingress class name   |  nginx / traefik                                                                         | used for TIBCO Control Plane                                                 |
| File storage class    |   azure-files-sc                                                                    | used for TIBCO Control Plane                                                                   |
| Disk storage class    |   azure-disk-sc                                                                    | used for TIBCO Control Plane                                                                   |
| Azure default storage class    | default                                                                      | Not recommended for TIBCO Control Plane                                                                |
| Postgres |  postgresql.tibco-ext.svc.cluster.local:5432   | used for TIBCO Control Plane |
| Postgres database@username:password |  postgres@postgres:postgres   | used for TIBCO Control Plane |
| Network Policies Details for Control Plane Namespace | [Control Plane Network Policies Document](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#Installation/control-plane-network-policies.htm) |

## Export additional variables required for chart values
```bash
## Configuration charts specific details
export TP_CONTAINER_REGISTRY_URL="csgprduswrepoedge.jfrog.io" # jfrog edge node url us-west-2 region, replace with container registry url as per your deployment region
export TP_CONTAINER_REGISTRY_USER="" # replace with your container registry username
export TP_CONTAINER_REGISTRY_PASSWORD="" # replace with your container registry password
export TP_CONTAINER_REGISTRY_REPOSITORY="tibco-platform-docker-prod" # replace with your container registry repository
```

## Create prerequisite secrets

### Generate and Create session-keys Secret (Required)
This secret is a required prerequisite for the tibco-cp-base chart. If this secret is not present in the Control Plane namespace, the router pods will fail to start correctly.
```bash
# Generate session keys and export as environment variables
export TSC_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)
export DOMAIN_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)

# Create the Kubernetes secret required by router pods, default secret name is session-keys
kubectl create secret generic session-keys -n ${CP_INSTANCE_ID}-ns \
  --from-literal=TSC_SESSION_KEY=${TSC_SESSION_KEY} \
  --from-literal=DOMAIN_SESSION_KEY=${DOMAIN_SESSION_KEY}
```

### Generate and Create cporch-encryption-secret (Required)
This secret is a required prerequisite for the tibco-cp-base chart.
```bash
# Generate encryption secret
export CP_ENCRYPTION_SECRET=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c44)

# Create secret in Control Plane namespace
kubectl create secret -n ${CP_INSTANCE_ID}-ns generic cporch-encryption-secret \
  --from-literal=CP_ENCRYPTION_SECRET=${CP_ENCRYPTION_SECRET}
```

## tibco-cp-base Chart values

Following values can be stored in a file and passed to the tibco-cp-base chart while deploying this chart.

> [!IMPORTANT]
> These values are for example only.

```bash
cat > azure-tibco-cp-base-values.yaml <(envsubst '${TP_ENABLE_NETWORK_POLICY}, ${TP_CONTAINER_REGISTRY_URL}, ${TP_CONTAINER_REGISTRY_USER}, ${TP_CONTAINER_REGISTRY_PASSWORD}, ${TP_CONTAINER_REGISTRY_REPOSITORY}, ${CP_INSTANCE_ID}, ${CP_TUNNEL_DNS_DOMAIN}, ${CP_MY_DNS_DOMAIN}, ${TP_VNET_CIDR}, ${TP_SERVICE_CIDR}, ${TP_FILE_STORAGE_CLASS}, ${TP_INGRESS_CLASS}, ${TP_LOGSERVER_ENDPOINT}, ${TP_LOGSERVER_INDEX}, ${TP_LOGSERVER_USERNAME}, ${TP_LOGSERVER_PASSWORD}'  << 'EOF'
hybrid-proxy:
  enabled: true
  ingress:
    enabled: true
    ingressClassName: ${TP_INGRESS_CLASS}
    tls:
      - secretName: tp-certificate-${CP_INSTANCE_ID}
        hosts:
          - '*.${CP_TUNNEL_DNS_DOMAIN}'
    ## uncomment annotations from following section, as per your requirements
    # annotations:
      ## annotations for `nginx` ingress class
      ## refer: https://github.com/kubernetes/ingress-nginx/blob/main/docs/user-guide/nginx-configuration/annotations.md to know more about the following annotation
      ## uncomment the following annotations, if not set globally using controller.config
      # nginx.ingress.kubernetes.io/proxy-buffer-size: 16k
      # nginx.ingress.kubernetes.io/proxy-body-size: "150m"
    hosts:
      - host: '*.${CP_TUNNEL_DNS_DOMAIN}'
        paths:
          - path: /
            pathType: Prefix
            port: 105
router-operator:
  enabled: true
  # SecretNames for environment variables TSC_SESSION_KEY and DOMAIN_SESSION_KEY.
  tscSessionKey:
    secretName: session-keys  # default secret name
    key: TSC_SESSION_KEY
  domainSessionKey:
    secretName: session-keys  # default secret name
    key: DOMAIN_SESSION_KEY
  ingress:
    enabled: true
    ingressClassName: "${TP_INGRESS_CLASS}"
    tls:
      - secretName: tp-certificate-${CP_INSTANCE_ID}
        hosts:
          - '*.${CP_MY_DNS_DOMAIN}'
    ## uncomment annotations from following section, as per your requirements
    # annotations:
      ## annotations for `nginx` ingress class
      ## refer: https://github.com/kubernetes/ingress-nginx/blob/main/docs/user-guide/nginx-configuration/annotations.md to know more about the following annotation
      ## uncomment the following annotations, if not set globally using controller.config
      # nginx.ingress.kubernetes.io/proxy-buffer-size: 16k
      # nginx.ingress.kubernetes.io/proxy-body-size: "150m"
    hosts:
      - host: '*.${CP_MY_DNS_DOMAIN}'
        paths:
          - path: /
            pathType: Prefix
            port: 100
# uncomment to enable logging
# otel-collector:
  # enabled: true
global:
  tibco:
    createNetworkPolicy: ${TP_ENABLE_NETWORK_POLICY}
    containerRegistry:
      url: "${TP_CONTAINER_REGISTRY_URL}"
      username: "${TP_CONTAINER_REGISTRY_USER}"
      password: "${TP_CONTAINER_REGISTRY_PASSWORD}"
      repository: "${TP_CONTAINER_REGISTRY_REPOSITORY}"
    controlPlaneInstanceId: "${CP_INSTANCE_ID}"
    serviceAccount: "${CP_INSTANCE_ID}-sa"
  external:
    clusterInfo:
      nodeCIDR: "${TP_VNET_CIDR}"
      podCIDR: "${TP_VNET_CIDR}"
      serviceCIDR: "${TP_SERVICE_CIDR}"
    dnsTunnelDomain: "${CP_TUNNEL_DNS_DOMAIN}"
    dnsDomain: "${CP_MY_DNS_DOMAIN}"
    storage:
      resources:
        requests:
          storage: 10Gi
      storageClassName: "${TP_FILE_STORAGE_CLASS}"
    # uncomment following section if logging is enabled
    # logserver:
    #   endpoint: ${TP_LOGSERVER_ENDPOINT}
    #   index: ${TP_LOGSERVER_INDEX}
    #   username: ${TP_LOGSERVER_USERNAME}
    #   password: ${TP_LOGSERVER_PASSWORD}
EOF
)
```

## Next Steps

Please proceed with deployment of TIBCO Control Plane on your AKS cluster as per [the steps mentioned in the document](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#Installation/deploying-control-plane-in-kubernetes.htm)

# Clean-up

Refer to [the steps to delete TIBCO Control Plane](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#Installation/uninstalling-tibco-control-plane.htm).

Change the directory to [aks/scripts/](../../aks/scripts/) to proceed with the next steps.
```bash
cd aks/scripts
```

> [!IMPORTANT]
> If you have used a common cluster for both TIBCO Control Plane and Data Plane, please check the script and add modifications
> so that common resources are not deleted. (e.g. storage class, File Storage, AKS Cluster etc.)

For the tools charts uninstallation, File storage mount and cluster deletion, we have provided a helper [clean-up](../scripts/clean-up.sh).

```bash
./clean-up.sh
```