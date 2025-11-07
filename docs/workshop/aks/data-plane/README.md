Table of Contents
=================
<!-- TOC -->
* [Table of Contents](#table-of-contents)
* [Data Plane Cluster Workshop](#data-plane-cluster-workshop)
  * [Export required variables](#export-required-variables)
  * [Install External DNS](#install-external-dns)
  * [Install Ingress Controller, Storage class](#install-ingress-controllers-storage-classes)
    * [Nginx Ingress Controller](#install-nginx-ingress-controller)
    * [Traefik Ingress Controller [OPTIONAL]](#install-traefik-ingress-controller-optional)
    * [Kong Ingress Controller [OPTIONAL]](#install-and-configure-kong-ingress-controller-for-user-apps)
      * [Create Certificate User-Apps Domain](#create-certificate-user-apps-domain-optional)
      * [Install Kong for User-Apps Domain](#install-kong-for-user-apps-domain)
      * [Additional Configuration To Send Traces Using Kong](#additional-configuration-to-send-traces-using-kong)
    * [Install Storage Classes](#install-storage-classes)
  * [Install Observability tools](#install-observability-tools)
    * [Install Elastic stack](#install-elastic-stack)
    * [Install Prometheus stack](#install-prometheus-stack)
  * [Information needed to be set on TIBCO® Data Plane](#information-needed-to-be-set-on-tibco-data-plane)
  * [Clean-up](#clean-up)
<!-- TOC -->

# Data Plane Cluster Workshop

The goal of this workshop is to provide hands-on experience to prepare an Azure Kubernetes cluster to be used as a Data Plane. In order to deploy Data Plane, you need to have some necessary tools installed. This workshop will guide you to install/use the necessary tools.

> [!Note]
> This workshop is NOT meant for production deployment.

To perform the steps mentioned in this workshop document, it is assumed you already have an AKS cluster created and can connect to it.

> [!IMPORTANT]
> To create AKS cluster and connect to it using kubeconfig, please refer [steps for AKS cluster creation](../cluster-setup/README.md#azure-kubernetes-service-cluster-creation)


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
export TP_RESOURCE_GROUP="" # resource group name
export TP_CLUSTER_NAME="" # name of the cluster provisioned, used for chart deployment
export TP_KUBERNETES_VERSION="1.33" # please refer: https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions?tabs=azure-cli; use 1.32 or above
export KUBECONFIG=`pwd`/${TP_CLUSTER_NAME}.yaml # kubeconfig saved as cluster name yaml

## Network specific variables
export TP_VNET_NAME="${TP_CLUSTER_NAME}-vnet" # name of VNet resource
export TP_VNET_CIDR="10.4.0.0/16" # CIDR of the VNet
export TP_SERVICE_CIDR="10.0.0.0/16" # CIDR for service cluster IPs
export TP_AKS_SUBNET_CIDR="10.4.0.0/20" # CIDR of the AKS subnet address space
export TP_APISERVER_SUBNET_CIDR="10.4.19.0/28" # CIDR of the kubernetes api server subnet address space
export TP_NETWORK_POLICY="" # possible values "" (to disable network policy), "calico"

## Tooling specific variables
export TP_TIBCO_HELM_CHART_REPO=https://tibcosoftware.github.io/tp-helm-charts # location of charts repo url
export TP_ES_RELEASE_NAME="dp-config-es" # name of dp-config-es release name

## Domain specific variables
export TP_DNS_RESOURCE_GROUP="" # resource group to be used for record-sets
export TP_TOP_LEVEL_DOMAIN="azure.example.com" # top level domain of TP_DOMAIN
export TP_SANDBOX="dp1" # subdomain prefix for TP_DOMAIN
export TP_MAIN_INGRESS_SANDBOX_SUBDOMAIN="department" # sandbox subdomain to be used
export TP_DOMAIN="${TP_MAIN_INGRESS_SANDBOX_SUBDOMAIN}.${TP_SANDBOX}.${TP_TOP_LEVEL_DOMAIN}" # domain to be used
export TP_INGRESS_CLASS="nginx" # name of main ingress class used by capabilities, use 'traefik'

## If you want to use different domains for user apps, please uncomment following 3 domain and ingress specific variables and adjust the values as required

# export TP_SECONDARY_INGRESS_CLASS="kong" # name of main ingress class used by capabilities, use 'traefik'
# export TP_SECONDARY_INGRESS_SANDBOX_SUBDOMAIN="department-apps" # sandbox subdomain to be used for user-apps
# export TP_SECONDARY_DOMAIN=${TP_SECONDARY_INGRESS_SANDBOX_SUBDOMAIN}.${TP_SANDBOX}.${TP_TOP_LEVEL_DOMAIN} # domain to be used for user-apps

# Storage specific variables
export TP_DISK_ENABLED="true" # to enable azure disk storage class
export TP_DISK_STORAGE_CLASS="azure-disk-sc" # name of azure disk storage class
export TP_FILE_ENABLED="true" # to enable azure files storage class
export TP_FILE_STORAGE_CLASS="azure-files-sc" # name of azure files storage class
export TP_STORAGE_ACCOUNT_NAME="" # replace with name of existing storage account to be used for azure file shares
export TP_STORAGE_ACCOUNT_RESOURCE_GROUP="" # replace with name of storage account resource group
```

## Install External DNS for Apps Domain [OPTIONAL]

> [!NOTE]
> In the chart installation commands starting in this section & continued in next sections, you will see labels added
> in the helm upgrade command i.e. --labels layer=number. Adding labels is supported in helm version v3.13 and above. Label
> numbers are added to identify the dependency of chart installations, so that uninstallation can be done in reverse
> sequence (starting with charts not labelled first).

If you are using a different ingress controller (e.g. kong) and domain for user applications, you need to install a separate release of [external-dns](https://github.com/kubernetes-sigs/external-dns/tree/master/charts/external-dns) so that record sets can be managed for this ingress controller, too.

```bash
helm upgrade --install --wait --timeout 1h --reuse-values \
  -n external-dns-system external-dns-apps external-dns \
  --labels layer=0 \
  --repo "https://kubernetes-sigs.github.io/external-dns" --version "1.15.2" -f - <<EOF
provider: azure
sources:
  - service
  - ingress
txtOwnerId: external-dns-apps # tp separate the record sets from earlier installation of external-dns
domainFilters:
- ${TP_SANDBOX}.${TP_TOP_LEVEL_DOMAIN} # must be the domain as we create DNS zone for apps
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
- "--ingress-class=${TP_SECONDARY_INGRESS_CLASS}"
- --txt-wildcard-replacement=wildcard # issue for Azure dns zone: https://github.com/kubernetes-sigs/external-dns/issues/2922
EOF
```

## Install Ingress Controller(s), Storage classes

In this section, we will install ingress controller and storage class. We have made a helm chart called `dp-config-aks` that encapsulates the installation of ingress controller and storage class.
It will create the following resources:
* ingress object which will be able to create Azure load balancer
* annotation for external-dns to create DNS record for the ingress
* storage class for Azure Disks
* storage class for Azure Files

### Install Nginx Ingress Controller
You can choose to install Nginx or Traefik as the ingress controller for routing traffic to Data Plane services using Azure load balancer.
> [!Note]
> If you want to use Traefik Ingress Controller instead of Nginx, Please skip this and proceed to [Traefik Ingress Controller ](#install-traefik-ingress-controller-optional) Section
```bash
## following section is required to send traces using nginx
## uncomment the below commented section to run/re-run the command, once DP_NAMESPACE is available
export DP_NAMESPACE="ns"

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
      # to support passing the incoming X-Forwarded-* headers to upstreams (required by apps swagger)
      use-forwarded-headers: "true"
      # to support large file upload from Control Plane
      proxy-body-size: "150m"
      # to set the size of the buffer used for reading the first part of the response received
      proxy-buffer-size: 16k
    extraArgs:
      # set the certificate you have created in ingress-system or Control Plane namespace
      default-ssl-certificate: ingress-system/tp-certificate-main-ingress
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
nginx                       k8s.io/ingress-nginx        <none>       2m18s
```

The `nginx` ingress class is the main ingress that DP will use.

> [!IMPORTANT]
> You will need to provide this ingress class name i.e. nginx to TIBCO® Control Plane when you deploy capability.


### Install Traefik Ingress Controller [OPTIONAL]

```bash
## following variable is required to send traces using traefik
## uncomment the below commented section to run/re-run the command, once DP_NAMESPACE is available
export DP_NAMESPACE="ns" # Replace with your Data Plane namespace

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
    - '--entryPoints.web.forwardedHeaders.insecure' # you can also use trustedIPs instead of insecure to trust the forwarded headers https://doc.traefik.io/traefik/routing/entrypoints/#forwarded-headers
    - '--serversTransport.insecureSkipVerify=true' # please refer https://doc.traefik.io/traefik/routing/overview/#transport-configuration
    - '--providers.kubernetesingress.ingressendpoint.publishedservice=ingress-system/dp-config-aks-ingress-traefik'
  tlsStore:
    default:
      defaultCertificate:
        # set the certificate you have created in ingress-system
        secretName: tp-certificate-main-ingress
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
traefik                     traefik.io/ingress-controller        <none>       2m18s
```

The `traefik` ingress class is the main ingress that DP will use.

> [!IMPORTANT]
> You will need to provide this ingress class name i.e. traefik to TIBCO® Control Plane when you deploy capability.


### Install and Configure Kong Ingress Controller for User-Apps [OPTIONAL]
* In this optional step, you can install additional Ingress Controller Kong, if you want to use it for User Applications (user-apps) domain.

#### Create Certificate User-Apps Domain

Depending upon the requirement, you need to create certificate for user-apps domain.

Create a certificate using the issuer created in [cluster setup document](../cluster-setup/README.md#install-cluster-issuer) which can be the default certificate for this additional ingress controller

```bash
kubectl apply -f - << EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: tp-certificate-secondary-ingress
  namespace: ingress-system
spec:
  secretName: tp-certificate-secondary-ingress
  issuerRef:
    name: "cic-cert-subscription-scope-production-main"
    kind: ClusterIssuer
  dnsNames:
    - '*.${TP_SECONDARY_DOMAIN}'
EOF
```

#### Install Kong for User-Apps Domain

```bash
helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ingress-kong dp-config-aks-kong dp-config-aks \
  --labels layer=1 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
clusterIssuer:
  create: false
httpIngress:
  enabled: false
kong:
  enabled: true
  secretVolumes:
  - tp-certificate-secondary-ingress
  env:
    ssl_cert: /etc/secrets/tp-certificate-secondary-ingress/tls.crt
    ssl_cert_key: /etc/secrets/tp-certificate-secondary-ingress/tls.key
  proxy:
    type: LoadBalancer
    annotations:
      external-dns.alpha.kubernetes.io/hostname: "*.${TP_SECONDARY_DOMAIN}"
      service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /healthz
    tls:
      enabled: true
    http:
      enabled: false
## following environment section is required to send traces using kong
## uncomment the below commented section to run/re-run the command
  # env:
  #   tracing_instrumentations: request,all
  #   tracing_sampling_rate: 1
EOF
```

#### Additional Configuration To Send Traces Using Kong
You will need to deploy the below KongClusterPlugin CR configurations for enabling the opentelemetry plugin on a service.

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
nginx                            k8s.io/ingress-nginx                      <none>       2m18s
kong                             ingress-controllers.konghq.com/kong       <none>       4m10s
```
The `kong` ingress class will be used by Data Plane for user-apps domain.

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

#### Verify Storage Classes Creation

Use the following command to get the storage class names.

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

# wait for eck-operator to be installed 
# verify it by checking the statefulset logs using following command
kubectl logs -n elastic-system sts/elastic-operator

# install dp-config-es
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n elastic-system ${TP_ES_RELEASE_NAME} dp-config-es \
  --labels layer=2 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
domain: ${TP_DOMAIN}
es:
  version: "8.17.3"
  ingress:
    ingressClassName: ${TP_INGRESS_CLASS}
    service: ${TP_ES_RELEASE_NAME}-es-http
  storage:
    name: ${TP_DISK_STORAGE_CLASS}
  # following are the default requests and limits for application container, uncomment and change as required
  # resources:
  #   requests:
  #     cpu: "100m"
  #     memory: "2Gi"
  #   limits:
  #     cpu: "1"
  #     memory: "2Gi"
kibana:
  version: "8.17.3"
  ingress:
    ingressClassName: ${TP_INGRESS_CLASS}
    service: ${TP_ES_RELEASE_NAME}-kb-http
  # following are the default requests and limits for application container, uncomment and change as required
  # resources:
  #   requests:
  #     cpu: "150m"
  #     memory: "1Gi"
  #   limits:
  #     cpu: "1"
  #     memory: "2Gi"
apm:
  enabled: true
  version: "8.17.3"
  ingress:
    ingressClassName: ${TP_INGRESS_CLASS}
    service: ${TP_ES_RELEASE_NAME}-apm-http
  # following are the default requests and limits for application container, uncomment and change as required
  # resources:
  #   requests:
  #     cpu: "50m"
  #     memory: "128Mi"
  #   limits:
  #     cpu: "250m"
  #     memory: "512Mi"
EOF
```
</details>

Use the following command to verify successful creation of index templates

```bash
kubectl get -n elastic-system IndexTemplates
```
Output should be inline with following results:
```
NAME                                         AGE
dp-config-es-jaeger-service-index-template   110d
dp-config-es-jaeger-span-index-template      110d
dp-config-es-user-apps-index-template        110d
```

Use the following command to verify successful creation of indices

```bash
kubectl  get -n elastic-system Indices
```

Output should be inline with following results:
```
NAME                    AGE
jaeger-service-000001   110d
jaeger-span-000001      110d
```

Use the following command to verify successful creation of index lifecycle policies

```bash
kubectl get -n elastic-system IndexLifecyclePolicies
```

Output should be inline with following results:
```
NAME                                             AGE
dp-config-es-jaeger-index-30d-lifecycle-policy   110d
dp-config-es-user-index-60d-lifecycle-policy     110d
```

> [!IMPORTANT]
> Any failure to create Indices, IndexTemplates, IndexLifecyclePolicies needs to be debugged.
> The easiest way is to check elastic-operator statefulset logs and if required, uninstalling
> and re-installing dp-config-es chart

Use the following command to get the host URL for Kibana
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
  # default values for grafana adminUser and adminPassword are as follows, uncomment and edit the values as per requirement.
  # adminUser: admin
  # adminPassword: prom-operator
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
  # uncomment following values for ingress, if you want to enable public endpoint for prometheus
  # ingress:
  #   enabled: true
  #   ingressClassName: ${TP_INGRESS_CLASS}
  #   hosts:
  #   - prometheus-internal.${TP_DOMAIN}
EOF
)
```
</details>

Use this command to get the host URL for Grafana
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
| Elastic Search password          | xxx                      | Elastic Search password in dp-config-es-es-elastic-user secret                                                     |
| Tracing server host  | https://dp-config-es-es-http.elastic-system.svc.cluster.local:9200               | Elastic Search internal endpoint                                         |
| Prometheus service internal endpoint | http://kube-prometheus-stack-prometheus.prometheus-system.svc.cluster.local:9090 | Prometheus service                                        |
| Prometheus public endpoint | https://prometheus-internal.\<BASE_FQDN\>  |  Prometheus ingress host, if ingress is enabled using values                                        |
| Grafana endpoint  | https://grafana.\<BASE_FQDN\> | Grafana ingress host (default username: admin & password: prom-operator)                                        |
| Grafana password  | xxx | Grafana password is in secret kube-prometheus-stack-grafana of prometheus-system namespace (username: admin & password: prom-operator) |
Network Policies Details for Data Plane Namespace | [Data Plane Network Policies Document](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#UserGuide/controlling-traffic-with-network-policies.htm) |

## Clean-up

Please delete the Data Plane from TIBCO® Control Plane UI.
Refer to [the steps to delete the Data Plane](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#UserGuide/deleting-data-planes.htm).

Change the directory to [scripts/aks/](../../scripts/aks/) to proceed with the next steps.
```bash
cd aks/scripts
```

> [!IMPORTANT]
> Please make sure the resources to be deleted are in started/scaled-up state (e.g. AKS cluster)

For the tools charts uninstallation, Azure file shares deletion and cluster deletion, we have provided a helper [clean-up](../scripts/clean-up.sh).

```bash
./clean-up.sh
```