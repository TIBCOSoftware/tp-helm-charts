Table of Contents
=================
<!-- TOC -->
* [Table of Contents](#table-of-contents)
* [Data Plane Cluster Workshop](#gke-cluster-creation)
  * [Introduction](#introduction)
  * [Command Line Tools required](#command-line-tools-required)
  * [Recommended IAM Policies](#recommended-iam-policies)
  * [Export required variables](#export-required-variables)
  * [Pre cluster creation script](#pre-cluster-creation-script)
  * [Create Google Kubernetes Engine (GKE) cluster](#create-google-kubernetes-engine-gke-cluster)
  * [Generate kubeconfig to connect to GKE cluster](#generate-kubeconfig-to-connect-to-gke-cluster)
  * [Create StorageClass](#create-storageclass)
  * [Install common third party tools](#install-common-third-party-tools)
  * [Install Ingress Controller](#install-ingress-controller)
    * [Setup DNS](#setup-dns)
    * [Nginx Ingress Controller](#install-nginx-ingress-controller)
    * [Traefik Ingress Controller [OPTIONAL]](#install-traefik-ingress-controller-optional)
  * [Install Observability tools](#install-observability-tools)
    * [Install Elastic stack](#install-elastic-stack)
    * [Install Prometheus stack](#install-prometheus-stack)
  * [Clean up](#clean-up)
<!-- TOC -->

# Data Plane Cluster Workshop

The goal of this document is to provide hands-on experience to create GKE cluster with necessary add-ons. This is a pre-requisite to deploy Data Plane. 

> [!Note]
> This workshop is NOT meant for production deployment.

## Introduction

In order to deploy Data Plane, you need to have a Kubernetes cluster and install the necessary tools. This workshop will guide you to create a Kubernetes cluster in Google Cloud Platform and install the necessary tools.

## Command Line Tools required

The steps mentioned below were run on a Macbook Pro linux/amd64 platform. The following tools are installed using [brew](https://brew.sh/):
* envsubst (part of homebrew gettext)
* jq (1.7)
* yq (v4.35.2)
* bash (5.2.15)
* gcloud (498.0.0)
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
  --build-arg KUBECTL_VERSION=${KUBECTL_VERSION} \
  -t workshop-cli-tools:latest --load .
```
And then below command to run a container
```bash
docker run -it workshop-cli-tools:latest /bin/bash
```


## Recommended IAM Policies
It is recommended to have the [Minimum IAM Policies](https://cloud.google.com/kubernetes-engine/docs/how-to/iam)

## Export required variables

Following variables are required to be set to run the scripts and are referred throughout the document.
Please set/adjust the values of the variables as expected.

> [!NOTE]
> We have used the prefix `TP_` for the required variables.
> It stands for "TIBCO PLATFORM".

```bash
## GCP specific variables
export GCP_REGION="us-west1" # region 
export GCP_SA_CERT_MANAGER_NAME="tp-cert-manager-sa"
export GCP_SA_EXTERNAL_DNS_NAME="tp-external-dns-sa"
export GCP_PROJECT_ID="" #GCP project ID

## Cluster configuration specific variables
export TP_CLUSTER_NAME="tp-cluster" # name of the cluster to be prvisioned, used for chart deployment
export TP_CLUSTER_VERSION="1.30.5-gke.1014001" # please refer: https://cloud.google.com/kubernetes-engine/versioning#specifying_cluster_version
export KUBECONFIG=`pwd`/${TP_CLUSTER_NAME}.yaml # kubeconfig saved as cluster name yaml

## Network specific variables
export TP_CLUSTER_VPC_CIDR="10.0.0.0/20" # CIDR for VPC
export TP_CLUSTER_CIDR="10.1.0.0/16" # clusterIpv4Cidr
export TP_CLUSTER_SERVICE_CIDR="10.2.0.0/20" # servicesIpv4Cidr
export TP_CLUSTER_DESIRED_CAPACITY="2" # Number of VM nodes in the GKE cluster
export TP_CLUSTER_INSTANCE_TYPE="e2-standard-4" # VM Size of nodes

## By default, only your public IP will be added to allow access to public cluster
export TP_AUTHORIZED_IP=""  # declare additional IPs to be whitelisted for accessing cluster

## Helm chart repo
export TP_TIBCO_HELM_CHART_REPO=https://tibcosoftware.github.io/tp-helm-charts # location of charts repo url

## Network policy enablement
export TP_ENABLE_NETWORK_POLICY="true" # For standard cluster, network policy is disabled by default, but we can enable it while creating cluster itself or can also be enabled later. https://cloud.google.com/kubernetes-engine/docs/how-to/network-policy#enabling_network_policy_enforcement ,

## Tooling specific variables
export TP_STORAGE_CLASS="standard-rwx-tp" # name of storage class

## If you want to use same domain for services and user apps
export TP_DOMAIN="dp1.gcp.example.com" # domain to be used
export TP_INGRESS_CLASS="nginx" # name of main ingress class used by capabilities, use 'traefik' for traefik ingress controller

## If you want to use different domain for services and user apps [OPTIONAL]
## Then Uncomment below and set values 
#export TP_DOMAIN="services.dp1.gcp.example.com" # domain to be used for services and capabilities
#export TP_APPS_DOMAIN="apps.dp1.gcp.example.com" # optional - apps dns domain if you want to use different IC for services and apps
#export TP_APPS_INGRESS_CLASS="kong" # name of secondary ingress class used by apps

export TP_VERSION_DP_CONFIG_ES="1.2.1"
export TP_ES_RELEASE_NAME="dp-config-es" # name of dp-config-es release name

export TP_CERTIFICATE_CLUSTER_ISSUER_EMAIL="test@cloud.com" # You must replace this email address with your own. It will be used to contact you in case of issues with your account or certificates, including expiry notification emails.
export TP_CERTIFICATE_CLUSTER_ISSUER="tp-prod" # name of clusterIssuer

```

> [!IMPORTANT]
> The scripts associated with the workshop are NOT idempotent.
> It is recommended to clean-up the existing setup to create a new one.
> In below steps, we will use the [gcloud tool](https://cloud.google.com/sdk/gcloud) which is a recommended tool by Google to create a GKE cluster.

You can login to gcloud and also set default project using below commands before proceeding with next steps
```bash
gcloud auth login #login to gcloud
gcloud config set project ${GCP_PROJECT_ID}  #set default project
```

Change the directory to [gke/scripts/](../../gke/scripts/) to proceed with the next steps.
```bash
cd gke/scripts
```

## Pre cluster creation script
Execute the script to enable/create following GKE resources
* Enable Kubernetes Engine API
* Enable Cloud Filestore API
* Create IAM Service Accounts for cert manager and external dns

```bash
./prepare-gke-sa.sh
```
It will take approximately 5 minutes to complete the configuration.

## Create Google Kubernetes Engine (GKE) cluster

Execute the script to create following GKE resources
* Create VPC
* Create Subnet
* Create Firewall Rule
* Create GKE cluster

> [!IMPORTANT]
> Please take a look at the values provided and comments to adjust the configuration accordingly.

```bash
./create-gke.sh
```

It will take approximately 20 minutes to create a GKE cluster.

## Generate kubeconfig to connect to GKE cluster

We can use the following command to generate kubeconfig file.
```bash
gcloud container clusters get-credentials ${TP_CLUSTER_NAME} --region=${TP_CLUSTER_REGION}
```

And check the connection to GKE cluster.
```bash
kubectl get nodes
```

## Create StorageClass

Create storage class
```bash
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${TP_STORAGE_CLASS}
parameters:
  tier: standard
  network: "projects/${GCP_PROJECT_ID}/global/networks/${TP_CLUSTER_NAME}" # GCP VPC network name
provisioner: filestore.csi.storage.gke.io
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: true
EOF
```


# Install common third party tools

Before we deploy ingress or observability tools on an empty GKE cluster; we need to install some basic tools.
* [cert-manager](https://cert-manager.io/docs/installation/helm/)
* [external-dns](https://github.com/kubernetes-sigs/external-dns/tree/master/charts/external-dns)

> [!NOTE]
> In the chart installation commands starting in this section & continued in next sections, you will see labels added
> in the helm upgrade command i.e. --labels layer=number. Adding labels is supported in helm version v3.13 and above. Label
> numbers are added to identify the dependency of chart installations, so that uninstallation can be done in reverse
> sequence (starting with charts not labelled first).

<summary>We can use the following commands to install these tools</summary>

```bash
# install cert-manager
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n cert-manager cert-manager cert-manager \
  --labels layer=0 \
  --repo "https://charts.jetstack.io" --version "v1.16.1" -f - <<EOF
installCRDs: true
serviceAccount:
  create: true
  name: cert-manager
  annotations:
    iam.gke.io/gcp-service-account: ${GCP_SA_CERT_MANAGER_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com
EOF

# install external-dns
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n external-dns-system external-dns external-dns \
  --labels layer=0 \
  --repo "https://kubernetes-sigs.github.io/external-dns" --version "1.15.0" -f - <<EOF
provider: google
sources:
  - service
  - ingress
extraArgs:
- --ingress-class=${TP_INGRESS_CLASS}
serviceAccount:
  create: true
  name: external-dns
  annotations:
    iam.gke.io/gcp-service-account: ${GCP_SA_EXTERNAL_DNS_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com
EOF

# upgrade external-dns [OPTIONAL]
# if you prefer to use different DNS for Services and User-App endpoints then you need to upgrade external-dns chart by adding the TP_APPS_INGRESS_CLASS in the ingress-class filter section
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n external-dns-system external-dns external-dns \
  --labels layer=0 \
  --repo "https://kubernetes-sigs.github.io/external-dns" --version "1.15.0" -f - <<EOF
provider: google
sources:
  - service
  - ingress
extraArgs:
- --ingress-class=${TP_INGRESS_CLASS}
- --ingress-class=${TP_APPS_INGRESS_CLASS}
serviceAccount:
  create: true
  name: external-dns
  annotations:
    iam.gke.io/gcp-service-account: ${GCP_SA_EXTERNAL_DNS_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com
EOF
```

<summary>Sample output of third party helm charts that we have installed in the GKE cluster</summary>

```bash
$ helm ls -A -a
NAME                                     	NAMESPACE          	REVISION	UPDATED                                	STATUS  	CHART                          	APP VERSION
cert-manager                             	cert-manager       	1       	2024-10-24 21:55:13.997845236 +0000 UTC	deployed	cert-manager-v1.16.1           	v1.16.1  
external-dns                             	external-dns-system	1       	2024-10-24 21:57:34.910890603 +0000 UTC	deployed	external-dns-1.15.0            	0.15.0      
```

# Install Ingress Controller

## Setup DNS
### If you want to use same domain for services and user apps
For this workshop we will use `dp1.gcp.example.com` as the domain name. We will use `*.dp1.gcp.example.com` as the wildcard domain name for all the DP capabilities.
We are using the following services in this workshop:
* [Google Cloud DNS Zones](https://cloud.google.com/dns/docs/overview/): to manage DNS. We register `gcp.example.com` in Google Cloud DNS Zones.
* [Let's Encrypt](https://cert-manager.io/docs/configuration/acme/dns01/google/): to manage SSL certificate. We will create a wildcard certificate for `*.dp1.gcp.example.com`.
* external-dns: to create DNS record in dns zone for the record set. It will automatically create DNS record for ingress objects.

### If you want to use different domain for services and user apps [OPTIONAL]
For this workshop we will use `services.dp1.gcp.example.com` as the domain name. We will use `*.services.dp1.gcp.example.com` as the wildcard domain name for all the DP servcies and capabilities. For user apps use `*.apps.dp1.gcp.example.com` as the wildcard domain name.
* [Google Cloud DNS Zones](https://cloud.google.com/dns/docs/overview/): to manage DNS. We register `gcp.example.com` in Google Cloud DNS Zones.  
* [Let's Encrypt](https://cert-manager.io/docs/configuration/acme/dns01/google/): to manage SSL certificate. We will create a wildcard certificate for services `*.services.dp1.gcp.example.com` and for user apps `*.apps.dp1.gcp.example.com`.
* external-dns: to create DNS record in dns zone for the record set. It will automatically create DNS record for ingress objects (Please udate the external-dns chart by adding the DNS record in domainFilters section).


<summary>We can use the following commands to create clusterIssuer and certificate</summary>

```bash

# create ingress namespace for certificate ( same namespace will be used to deploy ingress)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ingress-system
EOF

# create ClusterIssuer
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ${TP_CERTIFICATE_CLUSTER_ISSUER}
spec:
  acme:
    # The ACME server URL
    server: https://acme-v02.api.letsencrypt.org/directory
    # Email address used for ACME registration
    email: ${TP_CERTIFICATE_CLUSTER_ISSUER_EMAIL}
    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: letsencrypt-prod
    # Enable the DNS-01 challenge provider
    solvers:
      - dns01:
          cloudDNS:
            # The ID of the GCP project
            project: ${GCP_PROJECT_ID}
EOF

# create main ingress certificate using above ClusterIssuer
kubectl apply -f  - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: tp-certificate-main-ingress
  namespace: ingress-system
spec:
  secretName: tp-certificate-main-ingress
  issuerRef:
    name: ${TP_CERTIFICATE_CLUSTER_ISSUER}
    kind: ClusterIssuer
  dnsNames:
    - '*.${TP_DOMAIN}'
EOF

# 
# create secondary ingress certificate using ClusterIssuer for apps domain [OPTIONAL]
# if you prefer to use different DNS for Services and User-App endpoints eg. kong then you can create certificate for secondary ingress
kubectl apply -f  - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: tp-certificate-secondary-ingress
  namespace: ingress-system
spec:
  secretName: tp-certificate-secondary-ingress
  issuerRef:
    name: ${TP_CERTIFICATE_CLUSTER_ISSUER}
    kind: ClusterIssuer
  dnsNames:
    - '*.${TP_APPS_DOMAIN}'
EOF
```

### Install Nginx Ingress Controller
* This can be used for both Data Plane Services and Apps
* Optionally, Nginx Ingress Controller can be used for Data Plane Services and Kong Ingress Controller for App Endpoints
> [!Note]
> If you want to use Traefik Ingress Controller instead of Nginx, Please skip this and procceed to [Traefik Ingress Controller ](#install-traefik-ingress-controller-optional) Section
```bash

## following section is required to send traces using nginx
## uncomment the below commented section to run/re-run the command, once DP_NAMESPACE is available
export DP_NAMESPACE="ns"

helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n ingress-system ingress-nginx ingress-nginx \
  --labels layer=0 \
  --repo "https://kubernetes.github.io/ingress-nginx" --version "4.11.3" -f - <<EOF
controller:
  allowSnippetAnnotations: true # https://github.com/kubernetes/ingress-nginx/pull/10393
  service:
    type: LoadBalancer
  ingressClass:
    - nginx
  extraArgs:
    default-ssl-certificate: ingress-system/tp-certificate-main-ingress
  config:
  # required by apps swagger
    use-forwarded-headers: "true"
  # # following section is required to send traces using nginx
  # # uncomment the below commented section to run/re-run the command, once DP_NAMESPACE is available
  #   enable-opentelemetry: "true"
  #   log-level: debug
  #   opentelemetry-config: /etc/nginx/opentelemetry.toml
  #   opentelemetry-operation-name: HTTP $request_method $service_name $uri
  #   opentelemetry-trust-incoming-span: "true"
  #   otel-max-export-batch-size: "512"
  #   otel-max-queuesize: "2048"
  #   otel-sampler: AlwaysOn
  #   otel-sampler-parent-based: "false"
  #   otel-sampler-ratio: "1.0"
  #   otel-schedule-delay-millis: "5000"
  #   otel-service-name: nginx-proxy
  #   otlp-collector-host: otel-userapp-traces.${DP_NAMESPACE}.svc
  #   otlp-collector-port: "4317"
  # opentelemetry:
  #   enabled: true
EOF
```

Use the following command to get the ingress class name.
```bash
$ kubectl get ingressclass
NAME                            CONTROLLER                                                     PARAMETERS   AGE
nginx                           k8s.io/ingress-nginx                                           <none>       24m
```
The `nginx` ingress class is the main ingress that DP will use.


### Install Traefik Ingress Controller [OPTIONAL]
* This can be used for both Data Plane Services and Apps
* Optionally, Traefik Ingress Controller can be used for Data Plane Services and Kong Ingress Controller for App Endpoints
```bash
## following variable is required to send traces using traefik
## uncomment the below commented section to run/re-run the command, once DP_NAMESPACE is available
export DP_NAMESPACE="ns" # Replace with your Data Plane namespace

helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ingress-system traefik traefik \
  --labels layer=1 \
  --repo "https://traefik.github.io/charts" --version "32.1.1" -f - <<EOF
hub:  # for hub
  enabled: false
service:  # for external-dns
  type: LoadBalancer
ingressClass:
  name: traefik
providers:  # for external service
  kubernetesIngress:
    allowExternalNameServices: true
additionalArguments:
  - '--entryPoints.websecure.forwardedHeaders.insecure' #You can also use trustedIPs instead of insecure to trust the forwarded headers https://doc.traefik.io/traefik/routing/entrypoints/#forwarded-headers
  - '--serversTransport.insecureSkipVerify=true'
  - '--providers.kubernetesingress.ingressendpoint.publishedservice=ingress-system/traefik'
tlsStore:
  default:
    defaultCertificate:
      secretName: tp-certificate-main-ingress
# # following section is required to send traces using traefik
# # uncomment the below commented section to run/re-run the command, once DP_NAMESPACE is available
# tracing:
#   otlp:
#     http:
#       endpoint: http://otel-userapp-traces.$\{DP_NAMESPACE\}.svc.cluster.local:4318/v1/traces
#   serviceName: traefik
EOF
```
Use the following command to get the ingress class name.
```bash
$ kubectl get ingressclass
NAME                        CONTROLLER                           PARAMETERS   AGE
traefik                     traefik.io/ingress-controller        <none>       2m18s
```

The `traefik` ingress class is the main ingress that DP will use.

### Install Kong Ingress Controller [OPTIONAL]
* In this optional step, you can install the Kong Ingress Controller if you want to use it for User App Endpoints, will be using secondary certificate 

```bash
## following variable is required to send traces using traefik
## uncomment the below commented section to run/re-run the command, once DP_NAMESPACE is available
export DP_NAMESPACE="ns" # Replace with your Data Plane namespace

helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ingress-system kong kong \
  --labels layer=1 \
  --repo https://charts.konghq.com --version "2.33.3" -f - <<EOF
ingressController:
  env:
    feature_gates: FillIDs=true,RewriteURIs=true
secretVolumes:
- tp-certificate-secondary-ingress
env:
  ssl_cert: /etc/secrets/tp-certificate-secondary-ingress/tls.crt
  ssl_cert_key: /etc/secrets/tp-certificate-secondary-ingress/tls.key
proxy:
  type: LoadBalancer
  tls:
    enabled: true
## following environment section is required to send traces using kong
## uncomment the below commented section to run/re-run the command
# env:
#   tracing_instrumentations: request,all
#   tracing_sampling_rate: 1
EOF
```

#### Following extra configuration is required to send traces using Kong
We need to deploy the below KongClusterPlugin CR configurations for enabling the opentelemetry plugin on a service.
Before applying the KongClusterPlugin, please modify the metadata.name & config.endpoint with the correct DP namespace.
To enable the BWCE app traces, please set ```BW_OTEL_TRACES_ENABLED``` env variable to true.
```bash
export DP_NAMESPACE="ns" # Replace with your Data Plane namespace 

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
    service.name: "kong-dev"  # This service name will get listed as a service name in Jaeger Query UI
  headers:
    X-Auth-Token: secret-token
  header_type: w3c  # Must be one of: preserve, ignore, b3, b3-single, w3c, jaeger, ot, aws, gcp, datadog
EOF
```

> Please refer the [Kong Documentation](https://docs.konghq.com/hub/kong-inc/opentelemetry/how-to/basic-example/) for more examples.

Use the following command to get the ingress class name.
```bash
$ kubectl get ingressclass
NAME    CONTROLLER                              PARAMETERS     AGE
nginx   k8s.io/ingress-nginx                      <none>       7h11m
kong    ingress-controllers.konghq.com/kong       <none>       7h10m
```
The `kong` ingress class is the ingress that DP will be used by user app endpoints.


## Install Observability tools

### Install Elastic stack

<summary>Use the following command to install Elastic stack</summary>

```bash
# install eck-operator
helm upgrade --install --wait --timeout 1h --labels layer=1 --create-namespace -n elastic-system eck-operator eck-operator --repo "https://helm.elastic.co" --version "2.14.0"

# install dp-config-es
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n elastic-system ${TP_ES_RELEASE_NAME} dp-config-es \
  --labels layer=2 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "1.2.1" -f - <<EOF
domain: ${TP_DOMAIN}
es:
  version: "8.15.2"
  ingress:
    ingressClassName: ${TP_INGRESS_CLASS}
    service: ${TP_ES_RELEASE_NAME}-es-http
  storage:
    name: ${TP_DISK_STORAGE_CLASS}
kibana:
  version: "8.15.2"
  ingress:
    ingressClassName: ${TP_INGRESS_CLASS}
    service: ${TP_ES_RELEASE_NAME}-kb-http
apm:
  enabled: true
  version: "8.15.2"
  ingress:
    ingressClassName: ${TP_INGRESS_CLASS}
    service: ${TP_ES_RELEASE_NAME}-apm-http
EOF
```

Use this command to get the host URL for Kibana
```bash
kubectl get ingress -n elastic-system dp-config-es-kibana -oyaml | yq eval '.spec.rules[0].host'
```

The username is normally `elastic`. We can use the following command to get the password.
```bash
kubectl get secret dp-config-es-es-elastic-user -n elastic-system -o jsonpath="{.data.elastic}" | base64 --decode; echo
```

### Install Prometheus stack


<summary>Use the following command to install Prometheus stack</summary>

```bash
# install prometheus stack
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n prometheus-system kube-prometheus-stack kube-prometheus-stack \
  --labels layer=2 \
  --repo "https://prometheus-community.github.io/helm-charts" --version "65.2.0" -f <(envsubst '${TP_DOMAIN}, ${TP_INGRESS_CLASS}' <<'EOF'
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

Use this command to get the host URL for Kibana
```bash
kubectl get ingress -n prometheus-system kube-prometheus-stack-grafana -oyaml | yq eval '.spec.rules[0].host'
```

The username is `admin`. And Prometheus Operator use fixed password: `prom-operator`.

## Clean up

Please delete the Data Plane from Control Plane UI.
Refer to [the steps to delete the Data Plane](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#UserGuide/deleting-data-planes.htm).

Change the directory to [gke/scripts/](../../gke/scripts/) to proceed with the next steps.
```bash
cd gke/scripts
```

For the cluster deletion and vpc and subnet cleanup, we have provided a helper [clean-up](gke/scripts/clean-gke.sh).
```bash
./delete-gke.sh
```
