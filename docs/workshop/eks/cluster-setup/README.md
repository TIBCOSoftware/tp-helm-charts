Table of Contents
=================
<!-- TOC -->
* [Table of Contents](#table-of-contents)
* [Amazon EKS Cluster Creation](#amazon-eks-cluster-creation)
  * [Introduction](#introduction)
  * [Command Line Tools required](#command-line-tools-required)
  * [Recommended IAM Policies](#recommended-iam-policies)
  * [Export required variables](#export-required-variables)
    * [Regarding Network Policy](#regarding-network-policy)
  * [Create Amazon Elastic Kubernetes Service (EKS) cluster](#create-amazon-elastic-kubernetes-service-eks-cluster)
  * [Generate kubeconfig to connect to EKS cluster](#generate-kubeconfig-to-connect-to-eks-cluster)
* [Install Third Party Tools](#install-third-party-tools)
  * [Install Cert Manager, Load-Balancer Controller, Metrics Server](#install-cert-manager-load-balancer-controller-metrics-server)
  * [Install Crossplane [OPTIONAL]](#install-crossplane-optional)
<!-- TOC -->

# Amazon EKS Cluster Creation

The goal of this document is to provide hands-on experience to create Amazon EKS cluster with necessary add-ons. This is a pre-requisite to deploy TIBCO® Control Plane and/or Data Plane. 

> [!Note]
> This workshop is NOT meant for production deployment.

## Introduction

In order to deploy TIBCO® Control Plane and/or Data Plane, you need to have a Kubernetes cluster and install the necessary tools. This workshop will guide you to create a Kubernetes cluster in AWS and install the necessary tools. After completing the steps from this document, you will need to follow separate steps for [TIBCO® Control Plane](../control-plane/) or [Data Plane](../data-plane/) setups.

## Command Line Tools required

The steps mentioned below were run on a Macbook Pro linux/amd64 platform. The following tools are installed using [brew](https://brew.sh/):
* envsubst (part of homebrew gettext)
* jq (1.7)
* yq (v4.35.2)
* bash (5.2.15)
* aws (aws-cli/2.15.32)
* eksctl (0.181.0)
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
  --build-arg AWS_CLI_VERSION=${AWS_CLI_VERSION} \
  --build-arg EKSCTL_VERSION=${EKSCTL_VERSION} \
  --build-arg KUBECTL_VERSION=${KUBECTL_VERSION} \
  -t workshop-cli-tools:latest --load .
```

## Recommended IAM Policies
It is recommended to have the [Minimum IAM Policies](https://eksctl.io/usage/minimum-iam-policies/) attached to the role which is being used for the cluster creation.
Additionally, you will need to add the [AmazonElasticFileSystemFullAccess](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonElasticFileSystemFullAccess.html) policy to the role you are going to use.
> [!NOTE]
> Please use this role with recommended IAM policies attached, to create and access EKS cluster

## Export required variables

Following variables are required to be set to run the scripts and are referred throughout the document.
Please set/adjust the values of the variables as expected.

> [!NOTE]
> We have used the prefix `TP_` for the required variables.
> It stands for "TIBCO PLATFORM".

```bash
## AWS specific configuration
export AWS_REGION="us-west-2" # aws region to be used for deployments
export TP_CLUSTER_REGION="${AWS_REGION}"

## Cluster configuration specific variables
export TP_VPC_CIDR="10.180.0.0/16" # vpc cidr for the cluster
export TP_SERVICE_CIDR="172.20.0.0/16" # service IPv4 cidr for the cluster
export TP_CLUSTER_NAME="eks-cluster-${TP_CLUSTER_REGION}" # name of the cluster to be prvisioned, used for chart deployment
export TP_KUBERNETES_VERSION="1.31" # please refer: https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html; use 1.30 or above
export TP_NODEGROUP_INSTANCE_TYPE="m5a.xlarge" # Instance type for the EC2 Machines, please refer https://aws.amazon.com/ec2/instance-types/ 
export TP_NODEGROUP_INITIAL_COUNT=3 # Number of desired nodes for the EKS cluster
export KUBECONFIG=`pwd`/${TP_CLUSTER_NAME}.yaml # kubeconfig saved as cluster name yaml

## Helm chart repo
export TP_TIBCO_HELM_CHART_REPO=https://tibcosoftware.github.io/tp-helm-charts # location of charts repo url

## Network policy enablement
export TP_ENABLE_NETWORK_POLICY="true"
```

> [!IMPORTANT]
> The scripts associated with the workshop are NOT idempotent.
> It is recommended to clean-up the existing setup to create a new one.

## Regarding Network Policy

Amazon VPC CNI plugin for Kubernetes is the only CNI plugin supported by Amazon EKS, as per https://docs.aws.amazon.com/eks/latest/userguide/alternate-cni-plugins.html
In this version of the workshop document, we will be using VPC CNI with enableNetworkPolicy configuration, as per the variable value set above for TP_ENABLE_NETWORK_POLICY.

In the previous versions of the workshop document, we were deploying Calico for network policies.
If you had deployed Calico, as per previous version document steps, you can remove Calico and decide to upgrade cluster.

Please proceed with the next steps in the [current directory](./).

## Create Amazon Elastic Kubernetes Service (EKS) cluster

In this step, we will use the [eksctl tool](https://eksctl.io/) which is a recommended tool by AWS to create an EKS cluster.

> [!IMPORTANT]
> Please take a look at the values provided and comments to adjust the configuration accordingly.

In the context of eksctl tool; they have a yaml file called `ClusterConfig object`.
This yaml file contains all the information needed to create an EKS cluster.
We have provided a yaml file [eksctl-recipe.yaml](./eksctl-recipe.yaml) for our workshop to bring up an EKS cluster.
We can use the following command to create an EKS cluster in your AWS account.

```bash
cat eksctl-recipe.yaml | envsubst | eksctl create cluster -f -
```

It will take approximately 30 minutes to create an EKS cluster.

## Generate kubeconfig to connect to EKS cluster

We can use the following command to generate kubeconfig file.
```bash
aws eks update-kubeconfig --region ${TP_CLUSTER_REGION} --name ${TP_CLUSTER_NAME} --kubeconfig "${KUBECONFIG}"
```

And check the connection to EKS cluster.
```bash
kubectl get nodes
```

# Install Third Party Tools

## Install Cert Manager, Load-Balancer Controller, Metrics Server

Before we deploy ingress or observability tools on an empty EKS cluster; we need to install some basic tools. 
* [cert-manager](https://cert-manager.io/docs/installation/helm/)
* [aws-load-balancer-controller](https://github.com/aws/eks-charts/tree/master/stable/aws-load-balancer-controller)
* [metrics-server](https://github.com/kubernetes-sigs/metrics-server/tree/master/charts/metrics-server)

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
serviceAccount:
  create: false
  name: cert-manager
EOF

# install aws-load-balancer-controller
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n kube-system aws-load-balancer-controller aws-load-balancer-controller \
  --labels layer=0 \
  --repo "https://aws.github.io/eks-charts" --version "1.6.0" -f - <<EOF
clusterName: ${TP_CLUSTER_NAME}
serviceAccount:
  create: false
  name: aws-load-balancer-controller
EOF

# install metrics-server
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n kube-system metrics-server metrics-server \
  --labels layer=0 \
  --repo "https://kubernetes-sigs.github.io/metrics-server" --version "3.11.0" -f - <<EOF
clusterName: ${TP_CLUSTER_NAME}
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
metrics-server              	kube-system        	1       	2023-10-23 12:19:14.648056 -0500 CDT	deployed	metrics-server-3.11.0             	0.6.4
```
</details>

## Install Crossplane [OPTIONAL]

For creating the AWS and Kubernetes resources in the EKS cluster, we can deploy [crossplane](https://docs.crossplane.io/latest/getting-started/introduction/) 

#### Pre-requisites

Navigate to the directory [../scripts](../scripts/).

Execute the following script which creates a configmap in the kube-system namespace with the name tibco-platform-infra to store
  1. AWS Account ID
  2. AWS Region
  3. Cluster Name
  4. Node CIDR
  5. Private Subnet IDs
  6. Public Subnet IDs
  7. VPC ID
  8. OIDC Details (Issuer hostpath, url and provider arn)

```bash
./get-cluster-details.sh
```

We need to create/use a role for crossplane which can be used to create AWS resources.
The role needs to have:
  1. EKS cluster OIDC provider in trust relationship
  2. Allowing account root to assume role in trust relationship
  3. Administrator policy attachment

To create the role, run the follwing script
```bash
./create-crossplane-role.sh
```
Script creates the IAM role with name in following format `${TP_CLUSTER_NAME}-crossplane-${TP_CLUSTER_REGION}`
e.g. cp-cluster-infra-crossplane-us-west-2

If you want to use a different role name, set the following variable before running the above script
```bash
export TP_CROSSPLANE_ROLE="" # expected role name
```

The same role name will have to be used in [Install AWS and Kubernetes providers](#install-aws-and-kubernetes-providers) and [Install AWS and Kubernetes provider configs](#install-aws-and-kubernetes-provider-configs) sections below.

> [!IMPORTANT]
> You will get an error for priviledge escalation, if you are using a role which does not have privileges to create a role and
> attach administrator policy. To work-around this you need to run the script assuming using a role which has equivalent privileges.

#### Install Crossplane

We will be using the following values to deploy `dp-config-aws` helm chart.

```bash
helm upgrade --install --wait --timeout 1h --create-namespace \
  -n crossplane-system crossplane dp-config-aws \
  --labels layer=0 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" --set crossplane.enabled=true
```

#### Install AWS and Kubernetes providers

Run the following command to ensure that Crossplane provider CRDs are ready
```bash
kubectl wait --for condition=established --timeout=300s crd/providers.pkg.crossplane.io

# Expected output
# customresourcedefinition.apiextensions.k8s.io/providers.pkg.crossplane.io condition met
```

We will install the following providers
[provider-aws](https://marketplace.upbound.io/providers/crossplane-contrib/provider-aws/v0.43.1)
[provider-kubernetes](https://marketplace.upbound.io/providers/crossplane-contrib/provider-kubernetes/v0.9.0)
and respective [controller configs](https://docs.crossplane.io/v1.13/concepts/providers/#controller-configuration)

```bash
helm upgrade --install --wait --timeout 1h \
  -n crossplane-system crossplane-providers dp-config-aws \
  --render-subchart-notes \
  --labels layer=1 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
crossplane-components:
  enabled: true
  providers:
    enabled: true
    iamRoleName: "" # add the role name you created for crossplane, in the pre-requisite step above
EOF
```

#### Install AWS and Kubernetes provider configs

Run the following command to ensure that AWS and Kubernetes provider CRDs are ready
```bash
kubectl wait --for condition=established --timeout=300s crd/providerconfigs.aws.crossplane.io

# Expected output
# customresourcedefinition.apiextensions.k8s.io/providerconfigs.aws.crossplane.io condition met

kubectl wait --for condition=established --timeout=300s crd/providerconfigs.kubernetes.crossplane.io

# Expected output
# customresourcedefinition.apiextensions.k8s.io/providerconfigs.kubernetes.crossplane.io condition met
```

We will install the [ProviderConfigs](https://docs.crossplane.io/v1.13/concepts/providers/#provider-configuration) for AWS and Kubernetes.
```bash
helm upgrade --install --wait --timeout 1h \
  -n crossplane-system crossplane-provider-configs dp-config-aws \
  --render-subchart-notes \
  --labels layer=2 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
crossplane-components:
  enabled: true
  configs:
    enabled: true
    iamRoleName: "" # add the role name you created for crossplane, in the pre-requisite step above
EOF
```

#### Install compositions for AWS resources
We will create [crossplane composite resource definitions (XRDs)](https://docs.crossplane.io/v1.13/concepts/composite-resource-definitions/) and [crossplane compositions](https://docs.crossplane.io/v1.13/concepts/compositions/) for
- EFS
- RDS database instance
- Redis replication group
- IAM role, policies and role-policy attachments
- SES email identity
- kubernetes storage class
- Kubernetes persistent volume
- kubernetes service account
```bash
helm upgrade --install --wait --timeout 1h \
  -n crossplane-system crossplane-compositions-aws dp-config-aws \
  --render-subchart-notes \
  --labels layer=3 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
crossplane-components:
  enabled: true
  compositions:
    enabled: true
EOF
```
