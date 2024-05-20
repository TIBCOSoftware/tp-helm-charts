Table of Contents
=================
<!-- TOC -->
* [Table of Contents](#table-of-contents)
* [Data Plane Cluster Workshop](#data-plane-cluster-workshop)
  * [Introduction](#introduction)
  * [Command Line Tools required](#command-line-tools-required)
  * [Recommended IAM Policies](#recommended-iam-policies)
  * [Export required variables](#export-required-variables)
  * [Create EKS cluster](#create-eks-cluster)
  * [Generate kubeconfig to connect to EKS cluster](#generate-kubeconfig-to-connect-to-eks-cluster)
  * [Install common third party tools](#install-common-third-party-tools)
  * [Install Ingress Controller, Storage Class](#install-ingress-controller-storage-class)
    * [Setup DNS](#setup-dns)
    * [Setup EFS](#setup-efs)
    * [Storage Class](#storage-class)
    * [Nginx Ingress Controller](#Install-Nginx-Ingress-Controller)
    * [Kong Ingress Controller [OPTIONAL]](#install-kong-ingress-controller-optional)
  * [Install Calico [OPTIONAL]](#install-calico-optional)
    * [Pre Installation Steps](#pre-installation-steps)
    * [Chart Installation Step](#chart-installation-step)
    * [Post Installation Steps](#post-installation-steps)
  * [Install Observability tools](#install-observability-tools)
    * [Install Elastic stack](#install-elastic-stack)
    * [Install Prometheus stack](#install-prometheus-stack)
    * [Install Opentelemetry Collector for metrics](#install-opentelemetry-collector-for-metrics)
  * [Information needed to be set on TIBCO® Control Plane](#information-needed-to-be-set-on-tibco®-control-plane)
  * [Clean up](#clean-up)
<!-- TOC -->

# Data Plane Cluster Workshop

The goal of this workshop is to provide hands-on experience to deploy a Data Plane cluster in AWS. This is the prerequisite for the Data Plane.

> [!Note]
> This workshop is NOT meant for production deployment.

## Introduction

In order to deploy Data Plane, you need to have a Kubernetes cluster and install the necessary tools. This workshop will guide you to create a Kubernetes cluster in AWS and install the necessary tools.

## Command Line Tools required

The steps mentioned below were run on a Macbook Pro linux/amd64 platform. The following tools are installed using [brew](https://brew.sh/):
* envsubst (part of homebrew gettext)
* jq (1.7)
* yq (v4.35.2)
* bash (5.2.15)
* aws (aws-cli/2.13.27)
* eksctl (0.162.0)
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
  --build-arg AWS_CLI_VERSION=${AWS_CLI_VERSION} \
  --build-arg EKSCTL_VERSION=${EKSCTL_VERSION} \
  -t workshop-cli-tools:latest --load .
```

> [!NOTE]
> Please use export AWS_PAGER="" within the container to disable the use of a pager

## Recommended IAM Policies
It is recommended to have the [Minimum IAM Policies](https://eksctl.io/usage/minimum-iam-policies/) attached to the role which is being used for the cluster creation.
Additionally, you will need to add the [AmazonElasticFileSystemFullAccess](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonElasticFileSystemFullAccess.html) policy to the role you are going to use.
> [!NOTE]
> Please use this role with recommended IAM policies attached, to create and access EKS cluster

## Export required variables
```bash
## AWS specific values
export DP_CLUSTER_REGION=us-west-2 # aws region to be used for deployment

## Cluster configuration specific variables
export DP_VPC_CIDR="10.200.0.0/16" # vpc cidr for the cluster
export DP_CLUSTER_NAME=dp-cluster # name of the cluster to be prvisioned, used for chart deployment
export KUBECONFIG=`pwd`/${DP_CLUSTER_NAME}.yaml # kubeconfig saved as cluster name yaml

## Tooling specific variables
export DP_TIBCO_HELM_CHART_REPO=https://tibcosoftware.github.io/tp-helm-charts # location of charts repo url
## If you want to use same domain for services and user apps
export DP_DOMAIN=dp1.aws.example.com # domain to be used
## If you want to use different domain for services and user apps [OPTIONAL]
export DP_DOMAIN=services.dp1.aws.example.com # domain to be used for services and capabilities
export DP_APPS_DOMAIN=apps.dp1.aws.example.com # optional - apps dns domain if you want to use different IC for services and apps
export DP_MAIN_INGRESS_CONTROLLER=alb # name of aws load balancer controller
export DP_EBS_ENABLED=true # to enable ebs storage class
export DP_STORAGE_CLASS=ebs-gp3 # name of ebs storge class
export DP_EFS_ENABLED=true # to enable efs storage class
export DP_STORAGE_CLASS_EFS=efs-sc # name of efs storge class
export DP_INSTALL_CALICO="true" # to deploy calico
export DP_INGRESS_CLASS=nginx # name of main ingress class used by capabilities 
export DP_ES_RELEASE_NAME="dp-config-es" # name of dp-config-es release name
```

> [!IMPORTANT]
> The scripts associated with the workshop are NOT idempotent.
> It is recommended to clean-up the existing setup to create a new one.

Change the directory to [eks/](../eks/) to proceed with the next steps.
```bash
cd /eks
```

## Create Amazon Elastic Kubernetes Service (EKS) cluster

In this step, we will use the [eksctl tool](https://eksctl.io/) which is a recommended tool by AWS to create an EKS cluster.

In the context of eksctl tool; they have a yaml file called `ClusterConfig object`. 
This yaml file contains all the information needed to create an EKS cluster. 
We have created a yaml file [eksctl-recipe.yaml](eksctl-recipe.yaml) for our workshop to bring up an EKS cluster for Data Plane.
We can use the following command to create an EKS cluster in your AWS account. 

```bash 
cat eksctl-recipe.yaml | envsubst | eksctl create cluster -f -
```

It will take approximately 30 minutes to create an EKS cluster.

## Generate kubeconfig to connect to EKS cluster

We can use the following command to generate kubeconfig file.
```bash
aws eks update-kubeconfig --region ${DP_CLUSTER_REGION} --name ${DP_CLUSTER_NAME} --kubeconfig "${KUBECONFIG}"
```

And check the connection to EKS cluster.
```bash
kubectl get nodes
```

## Install common third party tools

Before we deploy ingress or observability tools on an empty EKS cluster; we need to install some basic tools. 
* [cert-manager](https://cert-manager.io/docs/installation/helm/)
* [external-dns](https://github.com/kubernetes-sigs/external-dns/tree/master/charts/external-dns)
* [aws-load-balancer-controller](https://github.com/aws/eks-charts/tree/master/stable/aws-load-balancer-controller)
* [metrics-server](https://github.com/kubernetes-sigs/metrics-server/tree/master/charts/metrics-server)

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
serviceAccount:
  create: false
  name: cert-manager
EOF

# install external-dns
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n external-dns-system external-dns external-dns \
  --labels layer=0 \
  --repo "https://kubernetes-sigs.github.io/external-dns" --version "1.13.0" -f - <<EOF
serviceAccount:
  create: false
  name: external-dns 
extraArgs:
  # add filter to only sync only public Ingresses with this annotation
  - "--annotation-filter=kubernetes.io/ingress.class=${DP_MAIN_INGRESS_CONTROLLER}"
EOF

# install aws-load-balancer-controller
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n kube-system aws-load-balancer-controller aws-load-balancer-controller \
  --labels layer=0 \
  --repo "https://aws.github.io/eks-charts" --version "1.6.0" -f - <<EOF
clusterName: ${DP_CLUSTER_NAME}
serviceAccount:
  create: false
  name: aws-load-balancer-controller
EOF

# install metrics-server
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n kube-system metrics-server metrics-server \
  --labels layer=0 \
  --repo "https://kubernetes-sigs.github.io/metrics-server" --version "3.11.0" -f - <<EOF
clusterName: ${DP_CLUSTER_NAME}
serviceAccount:
  create: true
  name: metrics-server
EOF
```
</details>

<details>

<summary>Sample output of third party helm charts that we have installed in the EKS cluster</summary>

```bash
$ helm ls -A -a
NAME                        	NAMESPACE          	REVISION	UPDATED                             	STATUS  	CHART                             	APP VERSION
aws-load-balancer-controller	kube-system        	1       	2023-10-23 12:17:13.149673 -0500 CDT	deployed	aws-load-balancer-controller-1.6.0	v2.6.0
cert-manager                	cert-manager       	2       	2023-10-23 12:10:33.504296 -0500 CDT	deployed	cert-manager-v1.12.3              	v1.12.3
external-dns                	external-dns-system	1       	2023-10-23 12:13:04.39863 -0500 CDT 	deployed	external-dns-1.13.0               	0.13.5
metrics-server              	kube-system        	1       	2023-10-23 12:19:14.648056 -0500 CDT	deployed	metrics-server-3.11.0             	0.6.4
```
</details>

## Install Ingress Controller, Storage Class

In this section, we will install ingress controller and storage class. We have made a helm chart called `dp-config-aws` that encapsulates the installation of ingress controller and storage class. 
It will create the following resources:
* a main ingress object which will be able to create AWS alb and act as a main ingress for DP cluster
* annotation for external-dns to create DNS record for the main ingress
* EBS with Amazon Elastic Block Store (EBS)
* EFS with Amazon Elastic File System (EFS)

### Setup DNS
## If you want to use same domain for services and user apps
Please use an appropriate domain name in place of `dp1.aws.example.com`. You can use `*.dp1.aws.example.com` as the wildcard domain name for all the DP services and capabilities.
## If you want to use different domain for services and user apps [OPTIONAL]
Please use an appropriate domain name in place of `services.dp1.aws.example.com`. You can use `*.services.dp1.aws.example.com` as the wildcard domain name for all the DP services and capabilities and for user app endpoints (`*.apps.dp1.aws.example.com`).

You can use the following services to register domain and manage certificates.
* [Amazon Route 53](https://aws.amazon.com/route53/): to manage DNS. You can register your Data Plane domain in Route 53. And give permission to external-dns to add new record.
* [AWS Certificate Manager (ACM)](https://docs.aws.amazon.com/acm/latest/userguide/acm-overview.html): to manage SSL certificate. You can create a wildcard certificate for `*.<DP_DOMAIN>` in ACM. Also if you want use another Domain for App endpoints you can create another wildcard certificate for `*.<DP_APPS_DOMAIN>` in ACM.
* aws-load-balancer-controller: to create AWS ALB. It will automatically create AWS ALB and add SSL certificate to ALB.
* external-dns: to create DNS record in Route 53. It will automatically create DNS record for ingress objects.

For this workshop, you will need to
* register a domain name in Route 53. You can follow this [link](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/domain-register.html) to register a domain name in Route 53.
* create a wildcard certificate in ACM. You can follow this [link](https://docs.aws.amazon.com/acm/latest/userguide/gs-acm-request-public.html) to create a wildcard certificate in ACM.

### Setup EFS
Before deploy `dp-config-aws`; we need to set up AWS EFS. For more information about EFS, please refer: 
* workshop to create EFS: [link](https://archive.eksworkshop.com/beginner/190_efs/launching-efs/)
* create EFS in AWS console: [link](https://docs.aws.amazon.com/efs/latest/ug/gs-step-two-create-efs-resources.html)
* create EFS with scripts: [link](https://github.com/kubernetes-sigs/aws-efs-csi-driver/blob/master/docs/efs-create-filesystem.md)

Change the directory to [scripts/eks/](../../scripts/eks) to proceed with the next steps.
```bash
cd scripts/eks
```

We provide an [EFS creation script](../../scripts/eks/create-efs-data-plane.sh) to create EFS. 
```bash
./create-efs-data-plane.sh
```

### Storage Class
After running above script; we will get an EFS ID output like `fs-0ec1c745c10d523f6`. We will need to use that value to deploy `dp-config-aws` helm chart.

```bash
## following variable is required to create the storage class
export DP_EFS_ID="fs-0ec1c745c10d523f6" # replace with the EFS ID created in your installation

helm upgrade --install --wait --timeout 1h --create-namespace \
  -n storage-system dp-config-aws-storage dp-config-aws \
  --repo "${DP_TIBCO_HELM_CHART_REPO}" \
  --labels layer=1 \
  --version "^1.0.0" -f - <<EOF
dns:
  domain: "${DP_DOMAIN}"
httpIngress:
  enabled: false
storageClass:
  ebs:
    enabled: ${DP_EBS_ENABLED}
  efs:
    enabled: ${DP_EFS_ENABLED}
    parameters:
      fileSystemId: "${DP_EFS_ID}"
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
```bash
## following variable is required to send traces using nginx
## uncomment the below commented section to run/re-run the command, once DP_NAMESPACE is available
export DP_NAMESPACE="ns" # Replace with your DP namespace

helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ingress-system dp-config-aws-nginx dp-config-aws \
  --repo "${DP_TIBCO_HELM_CHART_REPO}" \
  --labels layer=1 \
  --version "^1.0.0" -f - <<EOF
dns:
  domain: "${DP_DOMAIN}"
httpIngress:
  enabled: true
  name: nginx
  backend:
    serviceName: dp-config-aws-nginx-ingress-nginx-controller
  annotations:
    alb.ingress.kubernetes.io/group.name: "${DP_DOMAIN}"
    external-dns.alpha.kubernetes.io/hostname: "*.${DP_DOMAIN}"
    # this will be used for external-dns annotation filter
    kubernetes.io/ingress.class: alb
ingress-nginx:
  enabled: true
  controller:
    config:
      # required by apps swagger
      use-forwarded-headers: "true"
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

### Install Kong Ingress Controller [OPTIONAL]
> [!Note]
> The IC will use the same ALB, if you want to use another ALB for DP_APPS_DOMAIN then we need to change the value of the "alb.ingress.kubernetes.io/group.name" annotation
* In this optional step, you can install the Kong Ingress Controller if you want to use it for User App Endpoints
```bash
helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ingress-kong dp-config-aws-kong dp-config-aws \
  --repo "${DP_TIBCO_HELM_CHART_REPO}" \
  --labels layer=1 \
  --version "^1.0.0" -f - <<EOF
dns:
  domain: "${DP_APPS_DOMAIN}"
httpIngress:
  enabled: true
  name: kong
  backend:
    serviceName: dp-config-aws-kong-kong-proxy
  annotations:
    alb.ingress.kubernetes.io/group.name: "${DP_DOMAIN}"
    external-dns.alpha.kubernetes.io/hostname: "*.${DP_APPS_DOMAIN}"
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
NAME    CONTROLLER                              PARAMETERS     AGE
alb     ingress.k8s.aws/alb                       <none>       7h12m
nginx   k8s.io/ingress-nginx                      <none>       7h11m
kong    ingress-controllers.konghq.com/kong       <none>       7h10m
```
The `kong` ingress class is the ingress that DP will be used by user app endpoints.

## Install Calico [OPTIONAL]
For network policies to take effect in the EKS cluster, we will need to deploy [calico](https://www.tigera.io/project-calico/).

### Pre Installation Steps
As we are using [Amazon VPC CNI](https://github.com/aws/amazon-vpc-cni-k8s) add-on version 1.11.0 or later, traffic flow to Pods on branch network interfaces is subject to Calico network policy enforcement if we set POD_SECURITY_GROUP_ENFORCING_MODE=standard for the Amazon VPC CNI add-on.

Use the following command to set the mode
```bash
kubectl set env daemonset aws-node -n kube-system POD_SECURITY_GROUP_ENFORCING_MODE=standard
```
> [!IMPORTANT]
> This change can be verified with new pods of aws-node re-starting, and a message appears in the terminal
> for daemonset.apps/aws-node env updated

### Chart Installation Step

We will be using the following values to deploy `dp-config-aws` helm chart.

```bash
helm upgrade --install --wait --timeout 1h --create-namespace \
  -n tigera-operator dp-config-aws-calico dp-config-aws \
  --labels layer=1 \
  --repo "${DP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
tigera-operator:
  enabled: ${DP_INSTALL_CALICO}
  installation:
    enabled: true
    kubernetesProvider: EKS
    cni:
      type: AmazonVPC
    calicoNetwork:
      bgp: Disabled
EOF
```
### Post Installation Steps

Run the following commands post chart installation

We will create a configuration file that needs to be applied to the cluster that grants the aws-node kubernetes clusterrole the permission to patch Pods.
```bash
cat >append.yaml<<EOF
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - patch
EOF
```

We will apply the updated permissions to the cluster.
```bash
kubectl apply -f <(cat <(kubectl get clusterrole aws-node -o yaml) append.yaml)
```

We will need to set the environment variable for the plugin.
```bash
kubectl set env daemonset aws-node -n kube-system ANNOTATE_POD_IP=true
```
> [!IMPORTANT]
> This change can be verified with new pods of aws-node re-starting and a message appears in the terminal
> for daemonset.apps/aws-node env updated

We need to restart the pod(s) of calico-kube-controllers. The easiest step would be to restart the deployment. Otherwise, the pod can also be individually deleted.
```bash
kubectl rollout restart deployment calico-kube-controllers -n calico-system
```

> [!IMPORTANT]
> To confirm that the vpc.amazonaws.com/pod-ips annotation is added to the new calico-kube-controllers pod
> Run the following command
```bash
kubectl describe pod calico-kube-controllers-<pod_identifier> -n calico-system | grep vpc.amazonaws.com/pod-ips
```
Output will be similar to below
```bash
vpc.amazonaws.com/pod-ips: 10.200.108.148
```
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
    name: ${DP_STORAGE_CLASS}
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

Use this command to get the host URL for Grafana
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
Network Policies Details for Data Plane Namespace | [Data Plane Network Policies Document](https://docs.tibco.com/emp/platform-cp/1.0.0/doc/html/UserGuide/controlling-traffic-with-network-policies.htm) | 

## Clean up

Please delete the Data Plane from TIBCO® Control Plane UI.
Refer to [the steps to delete the Data Plane](https://docs.tibco.com/emp/platform-cp/1.0.0/doc/html/Default.htm#UserGuide/deleting-data-planes.htm?TocPath=Managing%2520Data%2520Planes%257C_____2).

Change the directory to [scripts/eks/](../../scripts/eks) to proceed with the next steps.
```bash
cd scripts/eks
```

For the tools charts uninstallation, EFS mount and security groups deletion and cluster deletion, we have provided a helper [clean-up](../../scripts/eks/clean-up-data-plane.sh).
```bash
./clean-up-data-plane.sh
```
