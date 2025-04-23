Table of Contents
=================
<!-- TOC -->
* [Table of Contents](#table-of-contents)
* [Data Plane EKS Workshop](#data-plane-eks-workshop)
  * [Export required variables](#export-required-variables)
  * [Install External DNS](#install-external-dns)
  * [Install Ingress Controller, Storage Class](#install-ingress-controller-storage-class)
    * [Setup DNS](#setup-dns)
      * [If you want to use same domain for services and user apps](#if-you-want-to-use-same-domain-for-services-and-user-apps)
      * [If you want to use different domain for services and user apps [OPTIONAL]](#if-you-want-to-use-different-domain-for-services-and-user-apps-optional)
    * [Create Amazon EFS](#create-amazon-efs)
    * [Create Storage Class](#create-storage-class)
    * [Install Nginx Ingress Controller](#install-nginx-ingress-controller)
    * [Install Traefik Ingress Controller [OPTIONAL]](#install-traefik-ingress-controller-optional)
    * [Install Kong Ingress Controller [OPTIONAL]](#install-kong-ingress-controller-optional)
      * [Following extra configuration is required to send traces using Kong](#following-extra-configuration-is-required-to-send-traces-using-kong)
  * [Install Observability tools](#install-observability-tools)
    * [Install Elastic stack](#install-elastic-stack)
    * [Install Prometheus stack](#install-prometheus-stack)
  * [Information needed to be set on TIBCO® Data Plane](#information-needed-to-be-set-on-tibco-data-plane)
  * [Clean up](#clean-up)
<!-- TOC -->

# Data Plane EKS Workshop

The goal of this workshop is to provide hands-on experience to prepare Amazon EKS cluster to be used as a Data Plane. In order to deploy Data Plane, you need to have a Kubernetes cluster with some necessary tools installed. This workshop will guide you to install the necessary tools.

> [!Note]
> This workshop is NOT meant for production deployment.

To perform the steps mentioned in this workshop document, it is assumed you already have an Amazon EKS cluster created and can connect to it.

> [!IMPORTANT]
> To create Amazon EKS cluster and connect to it using kubeconfig, please refer [steps for EKS cluster creation](../cluster-setup/README.md#amazon-eks-cluster-creation)

## Export required variables
Following variables are required to be set to run the scripts and are referred throughout the document.
Please set/adjust the values of the variables as expected.

> [!NOTE]
> We have used the prefixes `TP_` and `DP_` for the required variables.
> These prefixes stand for "TIBCO PLATFORM" and "Data Plane" respectively.

```bash
## AWS specific values
export AWS_REGION="us-west-2" # aws region to be used for deployments
export TP_CLUSTER_REGION="${AWS_REGION}"

## Cluster configuration specific variables
export TP_VPC_CIDR="10.200.0.0/16" # vpc cidr for the EKS cluster
export TP_SERVICE_CIDR="172.20.0.0/16" # service IPv4 cidr for the cluster
export TP_CLUSTER_NAME="eks-cluster-${CLUSTER_REGION}" # name of the EKS cluster prvisioned, used for chart deployment
export KUBECONFIG=`pwd`/${TP_CLUSTER_NAME}.yaml # kubeconfig saved for cluster

## Tooling specific variables
export TP_TIBCO_HELM_CHART_REPO=https://tibcosoftware.github.io/tp-helm-charts # location of charts repo url
## If you want to use same domain for services and user apps
export TP_DOMAIN=dp1.aws.example.com # domain to be used
## If you want to use different domain for services and user apps [OPTIONAL]
export TP_DOMAIN=services.dp1.aws.example.com # domain to be used for services and capabilities
export TP_APPS_DOMAIN=apps.dp1.aws.example.com # optional - apps dns domain if you want to use different IC for services and apps
export TP_MAIN_INGRESS_CONTROLLER=alb # name of aws load balancer controller
export TP_EBS_ENABLED=true # to enable ebs storage class
export TP_STORAGE_CLASS=ebs-gp3 # name of ebs storge class
export TP_EFS_ENABLED=true # to enable efs storage class
export TP_STORAGE_CLASS_EFS=efs-sc # name of efs storge class
export TP_INGRESS_CLASS=nginx # name of main ingress class used by capabilities, use 'traefik' for traefik ingress controller
export TP_ES_RELEASE_NAME="dp-config-es" # name of dp-config-es release name
```

## Install External DNS

Before creating ingress on this EKS cluster, we need to install [external-dns](https://github.com/kubernetes-sigs/external-dns/tree/master/charts/external-dns)

> [!NOTE]
> In the chart installation commands starting in this section & continued in next sections, you will see labels added
> in the helm upgrade command i.e. --labels layer=number. Adding labels is supported in helm version v3.13 and above. Label
> numbers are added to identify the dependency of chart installations, so that uninstallation can be done in reverse
> sequence (starting with charts not labelled first).


```bash
# install external-dns
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n external-dns-system external-dns external-dns \
  --labels layer=0 \
  --repo "https://kubernetes-sigs.github.io/external-dns" --version "1.15.2" -f - <<EOF
serviceAccount:
  create: false
  name: external-dns 
extraArgs:
  # add filter to only sync only public Ingresses with this annotation
  - "--annotation-filter=kubernetes.io/ingress.class=${TP_MAIN_INGRESS_CONTROLLER}"
EOF
```

## Install Ingress Controller, Storage Class

In this section, we will install ingress controller and storage class. We have provided a helm chart called `dp-config-aws` that encapsulates the installation of ingress controller and storage class. 
It will create the following resources:
* a main ingress object which will be able to create AWS Application Load Balancer (ALB) and act as an ingress controller for Data Plane cluster
* annotation for external-dns to create DNS record for the main ingress
* EBS with Amazon Elastic Block Store (EBS)
* EFS with Amazon Elastic File System (EFS)

### Setup DNS
#### If you want to use same domain for services and user apps
Please use an appropriate domain name in place of `dp1.aws.example.com`. You can use `*.dp1.aws.example.com` as the wildcard domain name for all the DP services and capabilities.
#### If you want to use different domain for services and user apps [OPTIONAL]
Please use an appropriate domain name in place of `services.dp1.aws.example.com`. You can use `*.services.dp1.aws.example.com` as the wildcard domain name for all the DP services and capabilities and for user app endpoints (`*.apps.dp1.aws.example.com`).

You can use the following services to register domain and manage certificates.
* [Amazon Route 53](https://aws.amazon.com/route53/): to manage DNS. You can register your Data Plane domain in Route 53. And give permission to external-dns to add new record.
* [AWS Certificate Manager (ACM)](https://docs.aws.amazon.com/acm/latest/userguide/acm-overview.html): to manage SSL certificate. You can create a wildcard certificate for `*.<TP_DOMAIN>` in ACM. Also if you want use another Domain for App endpoints you can create another wildcard certificate for `*.<TP_APPS_DOMAIN>` in ACM.
* aws-load-balancer-controller: to create AWS ALB. It will automatically create AWS ALB and add SSL certificate to ALB.
* external-dns: to create DNS record in Route 53. It will automatically create DNS record for ingress objects.

For this workshop, you will need to
* register a domain name in Route 53. You can follow this [link](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/domain-register.html) to register a domain name in Route 53.
* create a wildcard certificate in ACM. You can follow this [link](https://docs.aws.amazon.com/acm/latest/userguide/gs-acm-request-public.html) to create a wildcard certificate in ACM.

### Create Amazon EFS
Before deploy `dp-config-aws`; we need to set up Amazon EFS. For more information about EFS, please refer:
* Workshop to create EFS: [link](https://archive.eksworkshop.com/beginner/190_efs/launching-efs/)
* Create EFS in AWS console: [link](https://docs.aws.amazon.com/efs/latest/ug/gs-step-two-create-efs-resources.html)
* Create EFS with script: [link](https://github.com/kubernetes-sigs/aws-efs-csi-driver/blob/master/docs/efs-create-filesystem.md)
* You can also use the [EFS creation script](../scripts/create-efs-data-plane.sh), we provided, to create EFS

Change the directory to [scripts/](../scripts/) and execute the script.
```bash
cd ../scripts/
./create-efs-data-plane.sh
```

* If you have installed crossplane, there is another way to create Amazon EFS and Storage class by creating crossplane claims [mentioned in the control-plane document](../control-plane/README.md#install-crossplane-claims).

### Create Storage Class
After running above script; we will get an EFS ID output like `fs-0ec1c745c10d523f6`. We will need to use that value to deploy `dp-config-aws` helm chart.

```bash
## following variable is required to create the storage class
export TP_EFS_ID="fs-0ec1c745c10d523f6" # replace with the EFS ID created in your installation

helm upgrade --install --wait --timeout 1h --create-namespace \
  -n storage-system dp-config-aws-storage dp-config-aws \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" \
  --labels layer=1 \
  --version "^1.0.0" -f - <<EOF
dns:
  domain: "${TP_DOMAIN}"
httpIngress:
  enabled: false
storageClass:
  ebs:
    enabled: ${TP_EBS_ENABLED}
  efs:
    enabled: ${TP_EFS_ENABLED}
    parameters:
      fileSystemId: "${TP_EFS_ID}"
tigera-operator:
  enabled: false
ingress-nginx:
  enabled: false
EOF
```

Use the following command to get the storage class name.

```bash
$ kubectl get storageclass
NAME            PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
ebs-gp3         ebs.csi.aws.com         Retain          WaitForFirstConsumer   true                   7h17m
efs-sc          efs.csi.aws.com         Delete          Immediate              false                  7h17m
gp2 (default)   kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false                  7h41m
```

We have some scripts in the recipe to create and setup EFS. The `dp-config-aws` helm chart will create all these storage classes.
* `ebs-gp3` is the storage class for EBS. This is used for
  * storage class for data while provisioning TIBCO Enterprise Message Service™ (EMS) capability
* `efs-sc` is the storage class for EFS. This is used for
  * artifactmanager while provisioning TIBCO BusinessWorks™ Container Edition capability
  * storage class for log while provisioning EMS capability
* `gp2` is the default storage class for EKS. AWS creates it by default and we don't recommend to use it.

> [!IMPORTANT]
> You will need to provide this storage class name to TIBCO® Control Plane when you deploy capability.

### Install Nginx Ingress Controller
* This can be used for both Data Plane Services and Apps
* Optionally, Nginx Ingress Controller can be used for Data Plane Services and Kong Ingress Controller for App Endpoints
> [!Note]
> If you want to use Traefik Ingress Controller instead of Nginx, Please skip this and procceed to [Traefik Ingress Controller ](#install-traefik-ingress-controller-optional) Section 
```bash
## following variable is required to send traces using nginx
## uncomment the below commented section to run/re-run the command, once DP_NAMESPACE is available
export DP_NAMESPACE="ns" # Replace with your Data Plane namespace

helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ingress-system dp-config-aws-nginx dp-config-aws \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" \
  --labels layer=1 \
  --version "^1.0.0" -f - <<EOF
dns:
  domain: "${TP_DOMAIN}"
httpIngress:
  enabled: true
  name: nginx
  backend:
    serviceName: dp-config-aws-nginx-ingress-nginx-controller
  annotations:
    alb.ingress.kubernetes.io/group.name: "${TP_DOMAIN}"
    external-dns.alpha.kubernetes.io/hostname: "*.${TP_DOMAIN}"
    # this will be used for external-dns annotation filter
    kubernetes.io/ingress.class: alb
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
#       enable-opentelemetry: "true"
#       log-level: debug
#       opentelemetry-config: /etc/nginx/opentelemetry.toml
#       opentelemetry-operation-name: HTTP $request_method $service_name $uri
#       opentelemetry-trust-incoming-span: "true"
#       otel-max-export-batch-size: "512"
#       otel-max-queuesize: "2048"
#       otel-sampler: AlwaysOn
#       otel-sampler-parent-based: "false"
#       otel-sampler-ratio: "1.0"
#       otel-schedule-delay-millis: "5000"
#       otel-service-name: nginx-proxy
#       otlp-collector-host: otel-userapp-traces.${DP_NAMESPACE}.svc
#       otlp-collector-port: "4317"
#     opentelemetry:
#       enabled: true
EOF
```
Use the following command to get the ingress class name.
```bash
$ kubectl get ingressclass
NAME    CONTROLLER             PARAMETERS   AGE
alb     ingress.k8s.aws/alb    <none>       7h12m
nginx   k8s.io/ingress-nginx   <none>       7h11m
```

The `nginx` ingress class is the main ingress that DP will use. The `alb` ingress class is used by AWS ALB ingress controller.

> [!IMPORTANT]
> You will need to provide this ingress class name i.e. nginx to TIBCO® Control Plane when you deploy capability.


### Install Traefik Ingress Controller [OPTIONAL]
* This can be used for both Data Plane Services and Apps
* Optionally, Traefik Ingress Controller can be used for Data Plane Services and Kong Ingress Controller for App Endpoints
```bash
## following variable is required to send traces using traefik
## uncomment the below commented section to run/re-run the command, once DP_NAMESPACE is available
export DP_NAMESPACE="ns" # Replace with your Data Plane namespace

helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ingress-system dp-config-aws-traefik dp-config-aws \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" \
  --labels layer=1 \
  --version "^1.0.0" -f - <<EOF
dns:
  domain: "${TP_DOMAIN}"
httpIngress:
  enabled: true
  name: traefik
  backend:
    serviceName: dp-config-aws-traefik
  annotations:
    alb.ingress.kubernetes.io/group.name: "${TP_DOMAIN}"
    external-dns.alpha.kubernetes.io/hostname: "*.${TP_DOMAIN}"
    # this will be used for external-dns annotation filter
    kubernetes.io/ingress.class: alb
traefik:
  enabled: true
  additionalArguments:
    - '--entryPoints.web.forwardedHeaders.insecure' #You can also use trustedIPs instead of insecure to trust the forwarded headers https://doc.traefik.io/traefik/routing/entrypoints/#forwarded-headers
    - '--serversTransport.insecureSkipVerify=true' #Please refer https://doc.traefik.io/traefik/routing/overview/#transport-configuration 
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
NAME      CONTROLLER                     PARAMETERS   AGE
alb       ingress.k8s.aws/alb            <none>       7h12m
traefik   traefik.io/ingress-controller  <none>       7h11m
```

The `traefik` ingress class is the main ingress that DP will use. The `alb` ingress class is used by AWS ALB ingress controller.

> [!IMPORTANT]
> You will need to provide this ingress class name i.e. traefik to TIBCO® Control Plane when you deploy capability.


### Install Kong Ingress Controller [OPTIONAL]
> [!Note]
> The ingress controller will use the same application load balancer (ALB), if you want to use another ALB for
> TP_APPS_DOMAIN then we need to change the value of the "alb.ingress.kubernetes.io/group.name" annotation
* In this optional step, you can install the Kong Ingress Controller if you want to use it for User App Endpoints
```bash
helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ingress-kong dp-config-aws-kong dp-config-aws \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" \
  --labels layer=1 \
  --version "^1.0.0" -f - <<EOF
dns:
  domain: "${TP_APPS_DOMAIN}"
httpIngress:
  enabled: true
  name: kong
  backend:
    serviceName: dp-config-aws-kong-kong-proxy
  annotations:
    alb.ingress.kubernetes.io/group.name: "${TP_DOMAIN}"
    external-dns.alpha.kubernetes.io/hostname: "*.${TP_APPS_DOMAIN}"
    # this will be used for external-dns annotation filter
    kubernetes.io/ingress.class: alb
ingress-nginx:
  enabled: false 
kong:
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
alb     ingress.k8s.aws/alb                       <none>       7h12m
nginx   k8s.io/ingress-nginx                      <none>       7h11m
kong    ingress-controllers.konghq.com/kong       <none>       7h10m
```
The `kong` ingress class is the ingress that DP will be used by user app endpoints.


## Install Observability tools

### Install Elastic stack

Please use the following command to install Elastic stack

```bash
# install eck-operator
helm upgrade --install --wait --timeout 1h --labels layer=1 --create-namespace -n elastic-system eck-operator eck-operator --repo "https://helm.elastic.co" --version "2.16.0"

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
    name: ${TP_STORAGE_CLASS}
kibana:
  version: "8.17.3"
  ingress:
    ingressClassName: ${TP_INGRESS_CLASS}
    service: ${TP_ES_RELEASE_NAME}-kb-http
apm:
  enabled: true
  version: "8.17.3"
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

Please use the following command to install Prometheus stack

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

Use this command to get the host URL for Grafana
```bash
kubectl get ingress -n prometheus-system kube-prometheus-stack-grafana -oyaml | yq eval '.spec.rules[0].host'
```

The username is `admin`. And Prometheus Operator use fixed password: `prom-operator`.

###
> [!IMPORTTANT]
> Please re-visit the sections [using Nginx](#install-nginx-ingress-controller) or [using Kong]
> (#following-extra-configuration-is-required-to-send-traces-using-kong), if you want to
> configure your Ingress Controllers to send traces

## Information needed to be set on TIBCO® Data Plane

You can get BASE_FQDN (fully qualified domain name) by running the following command:
```bash
kubectl get ingress -n ingress-system nginx |  awk 'NR==2 { print $3 }'
```

| Name                 | Sample value                                                                     | Notes                                                                     |
|:---------------------|:---------------------------------------------------------------------------------|:--------------------------------------------------------------------------|
| VPC_CIDR             | 10.200.0.0/16                                                                    | from EKS recipe                                         |
| Ingress class name   | nginx                                                                            | used for TIBCO BusinessWorks™ Container Edition                                                     |
| Ingress class name (Optional)   | kong                                                                            | used for User App Endpoints                                            |
| EFS storage class    | efs-sc                                                                           | used for TIBCO BusinessWorks™ Container Edition and TIBCO Enterprise Message Service™ (EMS) EFS storage                                         |
| EBS storage class    | ebs-gp3                                                                          | used for TIBCO Enterprise Message Service™ (EMS)|
| BW FQDN              | bwce.\<BASE_FQDN\>                                                               | Capability FQDN |
| Elastic User app logs index   | user-app-1                                                                       | dp-config-es index template (value configured with o11y-data-plane-configuration in TIBCO® Control Plane)                               |
| Elastic Search logs index     | service-1                                                                        | dp-config-es index template (value configured with o11y-data-plane-configuration in TIBCO® Control Plane)                               |
| Elastic Search internal endpoint | https://dp-config-es-es-http.elastic-system.svc.cluster.local:9200               | Elastic Search service                                                |
| Elastic Search public endpoint   | https://elastic.\<BASE_FQDN\>                                                    | Elastic Search ingress host                                                |
| Elastic Search password          | xxx                                                                              | Elastic Search password in dp-config-es-es-elastic-user secret                                             |
| Tracing server host  | https://dp-config-es-es-http.elastic-system.svc.cluster.local:9200               | Elastic Search internal endpoint                                         |
| Prometheus service internal endpoint | http://kube-prometheus-stack-prometheus.prometheus-system.svc.cluster.local:9090 | Prometheus service                                        |
| Prometheus public endpoint | https://prometheus-internal.\<BASE_FQDN\>  |  Prometheus ingress host                                        |
| Grafana endpoint  | https://grafana.\<BASE_FQDN\> | Grafana ingress host                                        |
Network Policies Details for Data Plane Namespace | [Data Plane Network Policies Document](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#UserGuide/controlling-traffic-with-network-policies.htm) |

## Clean-up

Please delete the Data Plane from TIBCO® Control Plane UI.
Refer to [the steps to delete the Data Plane](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#UserGuide/deleting-data-planes.htm).

Change the directory to [scripts/](../scripts/) to proceed with the next steps.
```bash
cd ../scripts/
```

Set the following variable with value false, if you want to keep the cluster and delete only the helm charts and AWS resources
```bash
export TP_DELETE_CLUSTER=false # default value is "true"
```

> [!IMPORTANT]
> If you have used a common cluster for both TIBCO Control Plane and Data Plane, please check the script and add modifications
> so that common resources are not deleted. (e.g. storage class, EFS, EKS Cluster, crossplane role, etc.)

For the tools charts uninstallation, EFS mount and security groups deletion and cluster deletion, we have provided a helper [clean-up](../scripts/clean-up-data-plane.sh).

> [!IMPORTANT]
> Please make sure the resources to be deleted are in started/scaled-up state (e.g. RDS DB cluster/instance, EKS cluster nodegroups)

```bash
./clean-up-data-plane.sh
```
