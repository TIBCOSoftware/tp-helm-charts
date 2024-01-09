Table of Contents
=================
<!-- TOC -->
* [Table of Contents](#table-of-contents)
* [Control Plane Cluster Workshop](#control-plane-cluster-workshop)
  * [Introduction](#introduction)
  * [Command Line Tools required](#command-line-tools-required)
  * [Recommended IAM Policies](#recommended-iam-policies)
  * [Export required variables](#export-required-variables)
  * [Create Amazon Elastic Kubernetes Service (EKS) cluster](#create-amazon-elastic-kubernetes-service-eks-cluster)
  * [Generate kubeconfig to connect to EKS cluster](#generate-kubeconfig-to-connect-to-eks-cluster)
  * [Install common third party tools](#install-common-third-party-tools)
  * [Install Ingress Controller, Storage Class](#install-ingress-controller-storage-class)
    * [Setup DNS](#setup-dns)
    * [Setup EFS](#setup-efs)
    * [Storage Class](#storage-class)
    * [Ingress Controller for MY Domain](#ingress-controller-for-my-domain)
    * [Ingress Controller for Admin Domain](#ingress-controller-for-admin-domain)
    * [Load Balancer for Tunnel](#load-balancer-for-tunnel)
  * [Install Calico [OPTIONAL]](#install-calico-optional)
    * [Pre Installation Steps](#pre-installation-steps)
    * [Chart Installation Step](#chart-installation-step)
    * [Post Installation Steps](#post-installation-steps)
  * [Information needed to be set on TIBCO® Control Plane](#information-needed-to-be-set-on-tibco®-control-plane)
  * [Clean up](#clean-up)
<!-- TOC -->

# Control Plane Cluster Workshop

The goal of this workshop is to provide hands-on experience to deploy a Control Plane cluster in AWS. This is the prerequisite for the Control Plane.

> [!Note]
> This workshop is NOT meant for production deployment.

## Introduction

In order to deploy Control Plane, you need to have a Kubernetes cluster and install the necessary tools. This workshop will guide you to create a Kubernetes cluster in AWS and install the necessary tools.

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
  --build-arg KUBECTL_VERSION=${KUBECTL_VERSION} \
  --build-arg HELM_VERSION=${HELM_VERSION} \
  --build-arg YQ_VERSION=${YQ_VERSION} \
  -t workshop-cli-tools:latest --load .
```

## Recommended IAM Policies
It is recommended to have the [Minimum IAM Policies](https://eksctl.io/usage/minimum-iam-policies/) attached to the role which is being used for the cluster creation.
Additionally, you will need to add the [AmazonElasticFileSystemFullAccess](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonElasticFileSystemFullAccess.html) policy to the role you are going to use.
> [!NOTE]
> Please use this role with recommended IAM policies attached, to create and access EKS cluster

## Export required variables
```bash
## Cluster configuration specific variables
export CP_VPC_CIDR="10.180.0.0/16" # vpc cidr for the cluster
export AWS_REGION=us-west-2 # aws region to be used for deployment
export CP_CLUSTER_NAME=cp-cluster # name of the cluster to be prvisioned, used for chart deployment
export KUBECONFIG=${CP_CLUSTER_NAME}.yaml # kubeconfig saved as cluster name yaml

## Tooling specific variables
#export TIBCO_CP_HELM_CHART_REPO=https://tibcosoftware.github.io/tp-helm-charts # location of charts repo url
export TIBCO_CP_HELM_CHART_REPO=https://syan-tibco.github.io/tp-helm-charts # location of charts repo url
#export CP_DOMAIN=cp1.aws.example.com # domain to be used
export CP_HOSTED_ZONE_DOMAIN=trop-dev.dataplanes.pro # domain to be used
export CP_DOMAIN=cp1.trop-dev.dataplanes.pro # domain to be used
export CP_ADMIN_DOMAIN=cp1.trop-dev.dataplanes.pro # domain to be used
export CP_MY_DOMAIN=my.cp1.trop-dev.dataplanes.pro # domain to be used
export CP_TUNNEL_DOMAIN=tunnel.cp1.trop-dev.dataplanes.pro # domain to be used
export MAIN_INGRESS_CONTROLLER=alb # name of aws load balancer controller
export CP_EBS_ENABLED=false # to enable ebs storage class
export CP_STORAGE_CLASS=ebs-gp3 # name of ebs storge class
export CP_EFS_ENABLED=true # to enable efs storage class
export CP_STORAGE_CLASS_EFS=efs-sc # name of efs storge class
export INSTALL_CALICO="true" # to deploy calico
export CP_INGRESS_CLASS=nginx # name of main ingress class used by capabilities 
export CP_ES_RELEASE_NAME="cp-config-es" # name of dp-config-es release name

## TIBCO® Control Plane RDS specific details
export CP_RDS_AVAILABILITY="public" # public or private
export CP_RDS_USERNAME="cp_rdsadmin"
export CP_RDS_MASTER_PASSWORD="cp_DBAdminPassword"
export CP_RDS_INSTANCE_CLASS="db.t3.medium"
export CP_RDS_PORT="5432"

## TIBCO® Control Plane Redis specific details
export CP_REDIS_CACHE_NODE_TYPE="cache.t4g.medium"
export CP_REDIS_PORT="6379"

## AWS specific values
export AWS_PAGER=""
export WAIT_FOR_RESOURCE_AVAILABLE="false"
```

> [!IMPORTANT]
> The scripts associated with the workshop are NOT idempotent.
> It is recommended to clean-up the existing setup to create a new one.

Change the directory to [eks/](../eks/) to proceed with the next steps.
```bash
cd /cp-cluster/eks
```

## Create Amazon Elastic Kubernetes Service (EKS) cluster

In this step, we will use the [eksctl tool](https://eksctl.io/) which is a recommended tool by AWS to create an EKS cluster.

In the context of eksctl tool; they have a yaml file called `ClusterConfig object`. 
This yaml file contains all the information needed to create an EKS cluster. 
We have created a yaml file [eksctl-recipe.yaml](eksctl-recipe.yaml) for our workshop to bring up an EKS cluster for Control Plane.
We can use the following command to create an EKS cluster in your AWS account. 

```bash 
cat eksctl-recipe.yaml | envsubst | eksctl create cluster -f -
```

It will take approximately 30 minutes to create an EKS cluster.

## Generate kubeconfig to connect to EKS cluster

We can use the following command to generate kubeconfig file.
```bash
aws eks update-kubeconfig --region ${AWS_REGION} --name ${CP_CLUSTER_NAME} --kubeconfig ${CP_CLUSTER_NAME}.yaml
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
  - "--domain-filter=${CP_HOSTED_ZONE_DOMAIN}"
EOF

# install aws-load-balancer-controller
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n kube-system aws-load-balancer-controller aws-load-balancer-controller \
  --labels layer=0 \
  --repo "https://aws.github.io/eks-charts" --version "1.6.0" -f - <<EOF
clusterName: ${CP_CLUSTER_NAME}
serviceAccount:
  create: false
  name: aws-load-balancer-controller
EOF

# install metrics-server
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n kube-system metrics-server metrics-server \
  --labels layer=0 \
  --repo "https://kubernetes-sigs.github.io/metrics-server" --version "3.11.0" -f - <<EOF
clusterName: ${CP_CLUSTER_NAME}
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
aws-load-balancer-controller	kube-system        	1       	2023-12-12 14:46:54.754464 +0530 IST	deployed	aws-load-balancer-controller-1.6.0	v2.6.0     
cert-manager                	cert-manager       	1       	2023-12-12 14:44:07.285084 +0530 IST	deployed	cert-manager-v1.12.3              	v1.12.3    
external-dns                	external-dns-system	1       	2023-12-12 14:45:43.863738 +0530 IST	deployed	external-dns-1.13.0               	0.13.5     
metrics-server              	kube-system        	1       	2023-12-12 14:47:36.236359 +0530 IST	deployed	metrics-server-3.11.0             	0.6.4
```
</details>

## Install Ingress Controller, Storage Class

In this section, we will install ingress controller and storage class. We have made a helm chart called `dp-config-aws` that encapsulates the installation of ingress controller and storage class. 
It will create the following resources:
* a main ingress object which will be able to create AWS alb and act as a main ingress for CP cluster
* annotation for external-dns to create DNS record for the main ingress
* EFS with Amazon Elastic File System (EFS)

### Setup DNS
Please use an appropriate domain name in place of `cp1.aws.example.com`. You can use `*.cp1.aws.example.com` as the wildcard domain name for all the CP capabilities.

You can use the following services to register domain and manage certificates.
* [Amazon Route 53](https://aws.amazon.com/route53/): to manage DNS. You can register your Control Plane domain in Route 53. And give permission to external-dns to add new record.
* [AWS Certificate Manager (ACM)](https://docs.aws.amazon.com/acm/latest/userguide/acm-overview.html): to manage SSL certificate. You can create a wildcard certificate for `*.<CP_DOMAIN>` in ACM.
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

We have provided an [EFS creation script](../../scripts/eks/create-efs.sh) to create EFS. 
```bash
./create-efs.sh "${CP_CLUSTER_NAME}"
```

### Storage Class
After running above script; we will get an EFS ID output like `fs-0a14e944c5e4f4d76`. We will need to use that value to deploy `dp-config-aws` helm chart.

```bash
## following variable is required to create the storage class
export CP_EFS_ID="fs-0a14e944c5e4f4d76" # replace with the EFS ID created in your installation

helm upgrade --install --wait --timeout 1h --create-namespace \
  -n storage-system dp-config-aws-storage dp-config-aws \
  --repo "${TIBCO_CP_HELM_CHART_REPO}" \
  --labels layer=1 \
  --version "1.0.23" -f - <<EOF
dns:
  domain: "${CP_DOMAIN}"
httpIngress:
  enabled: false
storageClass:
  ebs:
    enabled: ${CP_EBS_ENABLED}
  efs:
    enabled: ${CP_EFS_ENABLED}
    parameters:
      fileSystemId: "${CP_EFS_ID}"
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
efs-sc          efs.csi.aws.com         Delete          Immediate              false                  2s
gp2 (default)   kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false                  4d11h
```

We have some scripts in the recipe to create and setup EFS. The `dp-config-aws` helm chart will create all these storage classes.
* `efs-sc` is the storage class for EFS. This is used
  *  while provisioning TIBCO® Control Plane
* `gp2` is the default storage class for EKS. AWS creates it by default and we don't recommend to use it.

### Ingress Controller for MY Domain
```bash

helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ingress-system dp-config-aws-my dp-config-aws \
  --repo "${TIBCO_CP_HELM_CHART_REPO}" \
  --labels layer=1 \
  --version "1.0.23" -f - <<EOF
dns:
  domain: "${CP_MY_DOMAIN}"
httpIngress:
  annotations:
    alb.ingress.kubernetes.io/group.name: "${CP_MY_DOMAIN}"
    external-dns.alpha.kubernetes.io/hostname: "*.${CP_MY_DOMAIN}"
    # this will be used for external-dns annotation filter
    kubernetes.io/ingress.class: alb
storageClass:
  ebs:
    enabled: false
  efs:
    enabled: false
tigera-operator:
  enabled: false
EOF
```

### Ingress Controller for ADMIN Domain
```bash

helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ingress-system dp-config-aws-admin dp-config-aws \
  --repo "${TIBCO_CP_HELM_CHART_REPO}" \
  --labels layer=1 \
  --version "1.0.23" -f - <<EOF
dns:
  domain: "${CP_ADMIN_DOMAIN}"
httpIngress:
  name: nginx-admin
  annotations:
    alb.ingress.kubernetes.io/group.name: "${CP_ADMIN_DOMAIN}"
    external-dns.alpha.kubernetes.io/hostname: "*.${CP_ADMIN_DOMAIN}"
    # this will be used for external-dns annotation filter
    kubernetes.io/ingress.class: alb
storageClass:
  ebs:
    enabled: false
  efs:
    enabled: false
tigera-operator:
  enabled: false
ingress-nginx:
  enabled: false
EOF
```

### Load Balancer for TUNNEL
```bash

helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ingress-system dp-config-aws-tunnel dp-config-aws \
  --repo "${TIBCO_CP_HELM_CHART_REPO}" \
  --version "1.0.23" \
  --labels layer=1 \
   -f - <<EOF
dns:
  domain: "${CP_TUNNEL_DOMAIN}"
httpIngress:
  enabled: false
service:
  enabled: true
  name: cp-tunnel-service
  type: LoadBalancer
  annotations:
    external-dns.alpha.kubernetes.io/hostname: "*.${CP_TUNNEL_DOMAIN}"
    service.beta.kubernetes.io/aws-load-balancer-attributes: load_balancing.cross_zone.enabled=false
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:us-west-2:910716586980:certificate/92e28570-3058-461e-b019-8cbdd68264fa"
    service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
    service.beta.kubernetes.io/aws-load-balancer-subnets: "eksctl-cp-cluster-cluster/SubnetPublicUSWEST2C, eksctl-cp-cluster-cluster/SubnetPublicUSWEST2D, eksctl-cp-cluster-cluster/SubnetPublicUSWEST2A"
    service.beta.kubernetes.io/aws-load-balancer-target-group-attributes: preserve_client_ip.enabled=true
    service.beta.kubernetes.io/aws-load-balancer-type: external
  selector:
    app.kubernetes.io/name: hybrid-proxy
  ports:
    hybrid-proxy:
      enabled: true
      containerPort: 443
      servicePort: 443
      protocol: TCP
storageClass:
  ebs:
    enabled: false
  efs:
    enabled: false
tigera-operator:
  enabled: false
ingress-nginx:
  enabled: false
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

### Create RDS instance

Change the directory to [scripts/eks/](../../scripts/eks) to proceed with the next steps.
```bash
cd scripts/eks
```

We have provided an [RDS creation script](../../scripts/eks/create-rds.sh) to create RDS instance.
```bash
export ${WAIT_FOR_RESOURCE_AVAILABLE}="false" # set to true to wait for resources to be available, before proceeding
./create-rds.sh
```

### Create Redis replication group
We have provided an [Redis creation script](../../scripts/eks/create-redis.sh) to create Redis replication group.
```bash
export ${WAIT_FOR_RESOURCE_AVAILABLE}="false" # set to true to wait for resources to be available, before proceeding
./create-redis.sh
```

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
  --repo "${TIBCO_CP_HELM_CHART_REPO}" --version "1.0.23" -f - <<EOF
ingress-nginx:
  enabled: false
httpIngress:
  enabled: false
service:
  enabled: false
storageClass:
  ebs:
    enabled: false
  efs:
    enabled: false
tigera-operator:
  enabled: ${INSTALL_CALICO}
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
vpc.amazonaws.com/pod-ips: 10.180.108.148
```

## Information needed to be set on TIBCO® Control Plane

You can get BASE_FQDN (fully qualified domain name) by running the following command:
```bash
kubectl get ingress -n ingress-system nginx |  awk 'NR==2 { print $3 }'
```

| Name                 | Sample value                                                                     | Notes                                                                     |
|:---------------------|:---------------------------------------------------------------------------------|:--------------------------------------------------------------------------|
| VPC_CIDR             | 10.180.0.0/16                                                                    | from EKS recipe                                                                                 |
| Ingress class name   | nginx                                                                            | used for TIBCO BusinessWorks™ Container Edition                                                 |
| EFS storage class    | efs-sc                                                                           | used for TIBCO® Control Plane                                                                   |
| RDS DB instance resource arn | arn:aws:rds:\<AWS_REGION\>:\<AWS_ACCOUNT_ID\>:db:${CP_CLUSTER_NAME}-db   | used for TIBCO® Control Plane                                                                   |
| Redis replication group resource arn | arn:aws:elasticache:\<AWS_REGION\>:\<AWS_ACCOUNT_ID\>:replicationgroup:${CP_CLUSTER_NAME}-redis                                                                                   | used for TIBCO® Control Plane                                                                   |
| Network Policies Details for Control Plane Namespace | [Control Plane Network Policies Document](https://docs.tibco.com/emp/platform-cp/1.0.0/doc/html/UserGuide/controlling-traffic-with-network-policies.htm) | 

## Clean up

Refer to [the steps to delete the Control Plane](https://docs.tibco.com/emp/platform-cp/1.0.0/doc/html/Default.htm#UserGuide/deleting-control-planes.htm?TocPath=Managing%2520Data%2520Planes%257C_____2).

Change the directory to [scripts/eks/](../../scripts/eks) to proceed with the next steps.
```bash
cd scripts/eks
```

For the tools charts uninstallation, EFS mount and security groups deletion and cluster deletion, we have provided a helper [clean-up](../../scripts/eks/clean-up-control-plane.sh).
```bash
./clean-up-control-plane.sh
```
