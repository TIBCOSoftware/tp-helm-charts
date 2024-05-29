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
  * [Install Common Third Party tools](#install-common-third-party-tools)
  * [Create-Configure AWS Resources](#create-configure-aws-resources)
    * [Using AWS CLI](#using-aws-cli)
      * [Create EFS](#setup-efs)
      * [Create RDS instance](#create-rds-instance)
    * [Using Crossplane](#using-crossplane)
      * [Pre-requisites](#pre-requisites)
      * [Install Crossplane](#install-crossplane)
      * [Install AWS and Kubernetes providers](#install-aws-and-kubernetes-providers)
      * [Install AWS and Kubernetes provider configs](#install-aws-and-kubernetes-provider-configs)
      * [Install compositions for AWS resources](#install-compositions-for-aws-resources)
      * [Install claims to create AWS resources](#install-claims-to-create-aws-resources)
        * [Pre-requisites to create namespace and service account](#pre-requisites-to-create-namespace-and-service-account)
        * [Install claims](#install-claims)
        * [Post resource creation](#post-resource-creation)
    * [Storage Class](#storage-class)
  * [Install Calico [OPTIONAL]](#install-calico-optional)
    * [Pre Installation Steps](#pre-installation-steps)
    * [Chart Installation Step](#chart-installation-step)
    * [Post Installation Steps](#post-installation-steps)
  * [Information needed to be set on TIBCO® Control Plane](#information-needed-to-be-set-on-tibco®-control-plane)
* [Control Plane Deployment](#control-plane-deployment)
  * [Configure Route53 records, Certificates](#configure-route53-records-certificates)
  * [Export additional variables required for chart values](#export-additional-variables-required-for-chart-values)
  * [Install Ingress Controller [OPTIONAL]](#install-ingress-controller-optional)
    * [Nginx Ingress Controller](#install-nginx-ingress-controller)
  * [Bootstrap Chart](#bootstrap-chart)
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
* aws (aws-cli/2.13.28)
* eksctl (0.176.0)
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

## Recommended IAM Policies
It is recommended to have the [Minimum IAM Policies](https://eksctl.io/usage/minimum-iam-policies/) attached to the role which is being used for the cluster creation.
Additionally, you will need to add the [AmazonElasticFileSystemFullAccess](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonElasticFileSystemFullAccess.html) policy to the role you are going to use.
> [!NOTE]
> Please use this role with recommended IAM policies attached, to create and access EKS cluster

## Export required variables
```bash
## AWS specific values
export AWS_PAGER=""
export AWS_REGION="us-west-2" # aws region to be used for deployment
export CP_CLUSTER_REGION="${AWS_REGION}" # aws region to be used for deployment
export WAIT_FOR_RESOURCE_AVAILABLE="false"

## Cluster configuration specific variables
export CP_VPC_CIDR="10.180.0.0/16" # vpc cidr for the cluster
export CP_CLUSTER_NAME=cp-cluster-infra # name of the cluster to be prvisioned, used for chart deployment
export KUBECONFIG=`pwd`/${CP_CLUSTER_NAME}.yaml # kubeconfig saved as cluster name yaml

## Helm repo specific details
export CP_TIBCO_HELM_CHART_REPO="https://tibcosoftware.github.io/tp-helm-charts" # location of charts repo url

## Domain, Storage related values and Network policy flag
export CP_HOSTED_ZONE_DOMAIN="aws.example.com" # replace with the Top Level Domain (TLD) to be used
export CP_STORAGE_CLASS_EFS=efs-sc # name of efs storge class
export CP_INSTALL_CALICO="false" # flag to deploy calico and deploy network policies

## TIBCO® Control Plane RDS specific details
export CP_RDS_AVAILABILITY="public" # public or private
export CP_RDS_USERNAME="cp_rdsadmin" # replace with desired username
export CP_RDS_MASTER_PASSWORD="cp_DBAdminPassword" # replace with desired username
export CP_RDS_INSTANCE_CLASS="db.t3.medium" # replace with desired db instance class
export CP_RDS_PORT="5432" # replace with desired db port

## Required by external-dns chart
export CP_MAIN_INGRESS_CONTROLLER=alb
export CP_INGRESS_CONTROLLER=nginx # This value can be same as CP_MAIN_INGRESS_CONTROLLER or nginx if you're using nginx

## Required for configuring Logserver for TIBCO® Control Plane services
export CP_LOGSERVER_ENDPOINT="" # logserver endpoint
export CP_LOGSERVER_INDEX="" # logserver index to push the logs to
export CP_LOGSERVER_USERNAME="" # logserver username
export CP_LOGSERVER_PASSWORD="" # logserver password

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
aws eks update-kubeconfig --region ${CP_CLUSTER_REGION} --name ${CP_CLUSTER_NAME} --kubeconfig "${KUBECONFIG}"
```

And check the connection to EKS cluster.
```bash
kubectl get nodes
```

## Install Common Third Party tools

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
  --repo "https://charts.jetstack.io" --version "v1.13.2" -f - <<EOF
installCRDs: true
serviceAccount:
  create: false
  name: cert-manager
EOF

# install external-dns
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n external-dns-system external-dns external-dns \
  --labels layer=0 \
  --repo "https://kubernetes-sigs.github.io/external-dns" --version "1.14.4" -f - <<EOF
serviceAccount:
  create: false
  name: external-dns 
extraArgs:
  # add filter to only sync only public Ingresses with this annotation
  - "--ingress-class=${CP_MAIN_INGRESS_CONTROLLER}"
sources:
  - ingress
  - service
domainFilters:
  - ${CP_HOSTED_ZONE_DOMAIN}
EOF

# install aws-load-balancer-controller
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n kube-system aws-load-balancer-controller aws-load-balancer-controller \
  --labels layer=0 \
  --repo "https://aws.github.io/eks-charts" --version "1.6.2" -f - <<EOF
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
NAME                        	NAMESPACE          	REVISION	UPDATED                                	STATUS  	CHART                             	APP VERSION
aws-load-balancer-controller	kube-system        	1       	2024-01-12 09:10:24.002048307 +0000 UTC	deployed	aws-load-balancer-controller-1.6.0	v2.6.0
cert-manager                	cert-manager       	1       	2024-01-12 09:07:02.96244632 +0000 UTC 	deployed	cert-manager-v1.12.3              	v1.12.3
external-dns                	external-dns-system	1       	2024-01-12 09:09:22.327909055 +0000 UTC	deployed	external-dns-1.13.0               	0.13.5
metrics-server              	kube-system        	1       	2024-01-12 09:11:57.458524202 +0000 UTC	deployed	metrics-server-3.11.0             	0.6.4
```
</details>

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
  --repo "${CP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
tigera-operator:
  enabled: ${CP_INSTALL_CALICO}
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

## Create-Configure AWS Resources

### Using AWS CLI
#### Create EFS
Before deploying `storage class`; we need to set up AWS EFS. For more information about EFS, please refer:
* workshop to create EFS: [link](https://archive.eksworkshop.com/beginner/190_efs/launching-efs/)
* create EFS in AWS console: [link](https://docs.aws.amazon.com/efs/latest/ug/gs-step-two-create-efs-resources.html)
* create EFS with scripts: [link](https://github.com/kubernetes-sigs/aws-efs-csi-driver/blob/master/docs/efs-create-filesystem.md)

Change the directory to [scripts/eks/](../../scripts/eks) to proceed with the next steps.
```bash
cd scripts/eks
```

We have provided an [EFS creation script](../../scripts/eks/create-efs-control-plane.sh) to create EFS.
```bash
./create-efs-control-plane.sh
```
#### Create RDS instance

Change the directory to [scripts/eks/](../../scripts/eks) to proceed with the next steps.
```bash
cd scripts/eks
```

We have provided a [RDS creation script](../../scripts/eks/create-rds.sh) to create RDS instance.
```bash
export ${WAIT_FOR_RESOURCE_AVAILABLE}="false" # set to true to wait for resources to be available, before proceeding
./create-rds.sh
```

> [!IMPORTANT]
> Please note that the RDS DB instance of PostgreSQL created using below crossplane claim does not enforce SSL by default.
> To enforce SSL connection, please check [Requiring an SSL connection to a PostgreSQL DB instance](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/PostgreSQL.Concepts.General.SSL.html#PostgreSQL.Concepts.General.SSL.Requiring)

### Using Crossplane

#### Pre-requisites

Change the directory to [scripts/eks/](../../scripts/eks) to proceed with the next steps.
```bash
cd scripts/eks
```

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
Script creates the IAM role with name in following format `${CP_CLUSTER_NAME}-crossplane-${CP_CLUSTER_REGION}`
e.g. cp-cluster-infra-crossplane-us-west-2

If you want to use a different role name, set the following variable before running the above script
```bash
export CP_CROSSPLANE_ROLE="" # expected role name
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
  --repo "${CP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" --set crossplane.enabled=true
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
  --repo "${CP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
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
  --repo "${CP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
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
- IAM role, policies and role-policy attachments
- SES email identity
- kubernetes storage class
- kubernetes service account
```bash
helm upgrade --install --wait --timeout 1h \
  -n crossplane-system crossplane-compositions-aws dp-config-aws \
  --render-subchart-notes \
  --labels layer=3 \
  --repo "${CP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
crossplane-components:
  enabled: true
  compositions:
    enabled: true
EOF
```
#### Install claims to create AWS resources

##### Pre-requisites to create namespace and service account

We will be creating a namespace where the crossplane claims are to be deployed.
This is the same namespace where the TIBCO® Control Plane charts are to be deployed too.

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

> [!IMPORTANT]
> If you have used crossplane to create service account, please skip running below script to create service account.

Create a service account in the namespace. This service account is used for TIBCO® Control Plane deployments.

```bash
kubectl create serviceaccount ${CP_INSTANCE_ID}-sa -n ${CP_INSTANCE_ID}-ns
```

##### Install claims

As part of claims, we will create following resources:
  1. Amazon Elastic File System (EFS)
  2. Amazon Relational Database Service (RDS) DB instance of PostgreSQL
  3. IAM Role and Policy Attachment
  4. Kubernete storage class using EFS ID created in (1)
  5. Kubernetes service account and annotate it with IAM Role ARN from (1)

This also creates the secrets in the namespace where the chart will be deployed.
TIBCO® Control Plane services can access these resources using the secrets.

> [!IMPORTANT]
> Please note that the RDS DB instance of PostgreSQL created using below crossplane claim does not enforce SSL by default.
> To enforce SSL connection, please check [Requiring an SSL connection to a PostgreSQL DB instance](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/PostgreSQL.Concepts.General.SSL.html#PostgreSQL.Concepts.General.SSL.Requiring)


```bash
export CP_RESOURCE_PREFIX="platform" # unique id to add to AWS resources as prefix (alphanumeric string of max 10 chars)

helm upgrade --install --wait --timeout 1h \
  -n ${CP_INSTANCE_ID}-ns crossplane-claims-aws dp-config-aws \
  --render-subchart-notes \
  --labels layer=4 \
  --repo "${CP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" \
  -f <(envsubst '${CP_INSTANCE_ID}, ${CP_RESOURCE_PREFIX}, ${CP_CLUSTER_NAME}, ${CP_STORAGE_CLASS_EFS}' <<'EOF'
crossplane-components:
  enabled: true
  claims:
    enabled: true
    commonResourcePrefix: "${CP_RESOURCE_PREFIX}"
    commonTags:
      cluster-name: ${CP_CLUSTER_NAME}
      owner: crossplane
    efs:
      create: true
      connectionDetailsSecret: "${CP_INSTANCE_ID}-efs-details"
      mandatoryConfigurationParameters:
        performanceMode: "generalPurpose"
        throughputMode: "elastic"
      additionalConfigurationParameters:
        encrypted: true
        kmsKeyId: ""
      storageClass:
        create: true
        name: "${CP_STORAGE_CLASS_EFS}"
      resourceTags:
        resource-name: efs
        cost-center: shared
    postgresInstance:
      create: true
      connectionDetailsSecret: "${CP_INSTANCE_ID}-rds-details"
      mandatoryConfigurationParameters:
        dbInstanceClass: "db.t3.medium"
        dbName: "postgres"
        engine: "postgres"
        engineVersion: "14.11"
        masterUsername: "useradmin"
        port: 5432
        publiclyAccessible: false
      resourceTags:
        resource-name: postgres-instance
        cost-center: control-plane
    iam:
      create: true
      connectionDetailsSecret: "${CP_INSTANCE_ID}-iam-details"
      mandatoryConfigurationParameters:
        serviceAccount:
          create: true
          name: ${CP_INSTANCE_ID}-sa
          namespace: ${CP_INSTANCE_ID}-ns
        policy:
          arns:
            - arn:aws:iam::aws:policy/AmazonSESFullAccess
      resourceTags:
        resource-name: iam-role
        cost-center: control-plane
EOF
)
```

> [!IMPORTANT]
> To use the parameter group with rds.force_ssl value "1" for the PostgreSQL DB instance, you need to set the value
> of spec.forProvider.dbParameterGroupName of the RDSInstance.database.aws.crossplane.io resource created using crossplane with this 
> parameter group name.
> You will also need to apply the modification for the RDS DB instance for it to come into effect from AWS console.

### Storage Class
> [!IMPORTANT]
> If you have used crossplane to create storage class, please skip running below script.

After running above script; we will get an EFS ID output like `fs-052ba079dbc2bffb4`.

```bash
## following variable is required to create the storage class
export CP_EFS_ID="fs-052ba079dbc2bffb4" # replace with the EFS ID created in your installation

kubectl apply -f <(envsubst '${CP_STORAGE_CLASS_EFS}, ${CP_EFS_ID}' <<'EOF'
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: "${CP_STORAGE_CLASS_EFS}"
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: efs.csi.aws.com
mountOptions:
  - soft
  - timeo=300
  - actimeo=1
parameters:
  provisioningMode: "efs-ap"
  fileSystemId: "${CP_EFS_ID}"
  directoryPerms: "700"
EOF
)
```

Use the following command to get the storage class name.

```bash
$ kubectl get storageclass
NAME            PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
efs-sc          efs.csi.aws.com         Delete          Immediate              false                  4s
gp2 (default)   kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false                  102m
```

We have some scripts in the recipe to create and setup EFS.
* `efs-sc` is the storage class for EFS. This is used
  *  while provisioning TIBCO® Control Plane
* `gp2` is the default storage class for EKS. AWS creates it by default and we don't recommend to use it.

Use the following command to get the ingress class name.
```bash
$ kubectl get ingressclass
NAME   CONTROLLER            PARAMETERS   AGE
alb    ingress.k8s.aws/alb   <none>       69m
```

The `alb` ingress class is used by AWS ALB ingress controller.

> [!IMPORTANT]
> The application load balancer fronting the application use this `alb` as the ingress class.

## Information needed to be set on TIBCO® Control Plane

| Name                 | Sample value                                                                     | Notes                                                                     |
|:---------------------|:---------------------------------------------------------------------------------|:--------------------------------------------------------------------------|
| VPC_CIDR             | 10.180.0.0/16                                                                    | from EKS recipe                                                                                 |
| Ingress class name   | alb / nginx                                                                           | used for TIBCO® Control Plane                                                 |
| EFS storage class    | efs-sc                                                                           | used for TIBCO® Control Plane                                                                   |
| RDS DB instance resource arn (if created using script) | arn:aws:rds:\<CP_CLUSTER_REGION\>:\<AWS_ACCOUNT_ID\>:db:${CP_CLUSTER_NAME}-db   | used for TIBCO® Control Plane |
| RDS DB details (if created using crossplane) | Secret `${CP_INSTANCE_ID}-rds-details` in `${CP_INSTANCE_ID}-ns` namespace Refer [Install claims](#install-claims) section  | used for TIBCO® Control Plane |
| Network Policies Details for Control Plane Namespace | [Control Plane Network Policies Document](https://docs.tibco.com/emp/platform-cp/1.2.0/doc/html/Default.htm#Installation/control-plane-network-policies.htm) |


# Control Plane Deployment

## Configure Route53 records, Certificates
We recommend that you use different Route53 records and certificates for `my` (control plane application) and `tunnel` (hybrid connectivity) domains. You can use wildcard domain names for these control plane application and hybrid connecivity domains.

We recommend that you use different `CP_INSTANCE_ID` to distinguish multiple control plane installations within a cluster.

Please export below variables and values related to domains:
```bash
## Domains
export CP_INSTANCE_ID="cp1" # unique id to identify multiple cp installation in same cluster (alphanumeric string of max 5 chars)
export CP_DOMAIN=${CP_INSTANCE_ID}-my.${CP_HOSTED_ZONE_DOMAIN} # domain to be used
export CP_TUNNEL_DOMAIN=${CP_INSTANCE_ID}-tunnel.${CP_HOSTED_ZONE_DOMAIN} # domain to be used
```
`CP_HOSTED_ZONE_DOMAIN` is exported as part of [Export required variables](#export-required-variables)

You can use the following services to register domain and manage certificates.
* [Amazon Route 53](https://aws.amazon.com/route53/): to manage DNS. You can register your Control Plane domain in Route 53. And, give permission to external-dns to add new record.
* [AWS Certificate Manager (ACM)](https://docs.aws.amazon.com/acm/latest/userguide/acm-overview.html): to manage SSL certificate. You can create wildcard certificates for `*.<CP_DOMAIN>` and `*.<CP_TUNNEL_DOMAIN>` in ACM.
* aws-load-balancer-controller: to create AWS ALB. It will automatically create AWS ALB and add SSL certificate to ALB.
* network-load-balancer service: to create AWS NLB. It will automatically create AWS NLB and add the SSL certificate provided in values.
* external-dns: to create DNS record in Route 53. It will automatically create DNS record for ingress objects and load balancer service..

For this workshop, you will need to
* register a domain name in Route 53. You can follow this [link](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/domain-register.html) to register a domain name in Route 53.
* create a wildcard certificate in ACM. You can follow this [link](https://docs.aws.amazon.com/acm/latest/userguide/gs-acm-request-public.html) to create a wildcard certificate in ACM.

## Export additional variables required for chart values
```bash
## Bootstrap and Configuration charts specific details
export CP_MAIN_INGRESS_CONTROLLER=alb
export CP_CONTAINER_REGISTRY_URL="csgprduswrepoedge.jfrog.io" # jfrog edge node url us-west-2 region, replace with container registry url as per your deployment region
export CP_CONTAINER_REGISTRY_USER="" # replace with your container registry username
export CP_CONTAINER_REGISTRY_PASSWORD="" # replace with your container registry password
export CP_DOMAIN_CERT_ARN="" # replace with your CP_DOMAIN certificate arn
export CP_TUNNEL_DOMAIN_CERT_ARN="" # replace with your CP_TUNNEL DOMAIN certificate arn
```

## Install Ingress Controller [OPTIONAL]

In this section, we will install ingress controller. We have made a helm chart called `dp-config-aws` that encapsulates the installation of ingress controller. 
It will create the following resources:
* a main ingress object which will be able to create AWS alb and act as a main ingress for CP cluster
* annotation for external-dns to create DNS record for the main ingress [external-dns chart is already deployed while installing [third party tools](#install-common-third-party-tools)]

### Install Nginx Ingress Controller
* This can be used for both Data Plane Services and Apps
* Optionally, Nginx Ingress Controller can be used for Data Plane Services and Kong Ingress Controller for App Endpoints
```bash

helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ingress-system dp-config-aws-nginx dp-config-aws \
  --repo "${CP_TIBCO_HELM_CHART_REPO}" \
  --labels layer=1 \
  --version "^1.0.0" -f - <<EOF
dns:
  domain: "${CP_DOMAIN}"
httpIngress:
  enabled: true
  name: nginx
  backend:
    serviceName: dp-config-aws-nginx-ingress-nginx-controller
  annotations:
    alb.ingress.kubernetes.io/group.name: "${CP_DOMAIN}"
    # this is to support 1.3 TLS for ALB, Please refer AWS doc: https://aws.amazon.com/about-aws/whats-new/2023/03/application-load-balancer-tls-1-3/
    alb.ingress.kubernetes.io/ssl-policy: "ELBSecurityPolicy-TLS13-1-2-2021-06"
    external-dns.alpha.kubernetes.io/hostname: "*.${CP_DOMAIN}"
    # this will be used for external-dns annotation filter
    kubernetes.io/ingress.class: alb
ingress-nginx:
  enabled: true
  controller:
    config:
      # to set maximum allowed size of the client request body to support large file upload
      proxy-body-size: "150m"
      # to passes the incoming X-Forwarded-* headers to upstreams
      use-forwarded-headers: "true"
EOF
```
Use the following command to get the ingress class name.
```bash
$ kubectl get ingressclass
NAME    CONTROLLER             PARAMETERS   AGE
alb     ingress.k8s.aws/alb    <none>       7h12m
nginx   k8s.io/ingress-nginx   <none>       7h11m
```

> [!IMPORTANT]
> You will need to provide this ingress class name i.e. nginx to TIBCO® Control Plane when you deploy capability.

## Bootstrap Chart

Following values can be stored in a file and passed to the platform-boostrap chart.

> [!IMPORTANT]
> These values are for example only.

```bash
cat > aws-bootstrap-values.yaml <(envsubst '${CP_INSTALL_CALICO}, ${CP_CONTAINER_REGISTRY_URL}, ${CP_CONTAINER_REGISTRY_USER}, ${CP_CONTAINER_REGISTRY_PASSWORD}, ${CP_INSTANCE_ID}, ${CP_TUNNEL_DOMAIN}, ${CP_DOMAIN}, ${CP_VPC_CIDR}, ${CP_STORAGE_CLASS_EFS}, ${CP_INGRESS_CONTROLLER}, ${CP_DOMAIN_CERT_ARN}, ${CP_TUNNEL_DOMAIN_CERT_ARN}, ${CP_LOGSERVER_ENDPOINT}, ${CP_LOGSERVER_INDEX}, ${CP_LOGSERVER_USERNAME}, ${CP_LOGSERVER_PASSWORD}'  << 'EOF'
tp-cp-bootstrap:
  # uncomment to enable logging
  # otel-collector:
    # enabled: true
global:
  tibco:
    createNetworkPolicy: ${CP_INSTALL_CALICO}
    containerRegistry:
      url: "${CP_CONTAINER_REGISTRY_URL}"
      username: "${CP_CONTAINER_REGISTRY_USER}"
      password: "${CP_CONTAINER_REGISTRY_PASSWORD}"
    controlPlaneInstanceId: "${CP_INSTANCE_ID}"
    logging:
      fluentbit:
        enabled: false # set to true to enable logging
    serviceAccount: "${CP_INSTANCE_ID}-sa"
  external:
    # uncomment following section if logging is enabled
    # logserver:
    #   endpoint: ${CP_LOGSERVER_ENDPOINT}
    #   index: ${CP_LOGSERVER_INDEX}
    #   username: ${CP_LOGSERVER_USERNAME}
    #   password: ${CP_LOGSERVER_PASSWORD}
    ingress:
      ingressClassName: "${CP_INGRESS_CONTROLLER}"
      certificateArn: "${CP_DOMAIN_CERT_ARN}"
      annotations: {}
        # optional policy to use TLS 1.3, if ingress class is `alb`
        # alb.ingress.kubernetes.io/ssl-policy: "ELBSecurityPolicy-TLS13-1-2-2021-06"
    aws:
      tunnelService:
        loadBalancerClass: "service.k8s.aws/nlb"
        certificateArn: "${CP_TUNNEL_DOMAIN_CERT_ARN}"
        annotations: {}
          # optional policy to use TLS 1.3, for `nlb`
          # service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy: "ELBSecurityPolicy-TLS13-1-2-2021-06"
    clusterInfo:
      nodeCIDR: "${CP_VPC_CIDR}"
      podCIDR: "${CP_VPC_CIDR}"
    dnsTunnelDomain: "${CP_TUNNEL_DOMAIN}"
    dnsDomain: "${CP_DOMAIN}"
    provider: "aws"
    storage:
      storageClassName: "${CP_STORAGE_CLASS_EFS}"
EOF
)
```

Please proceed with deployment of TIBCO® Control Plane on your EKS cluster as per [the steps mentioned in the document](https://docs.tibco.com/emp/platform-cp/1.2.0/doc/html/Default.htm#Installation/deploying-control-plane-in-kubernetes.htm)

# Clean up

Refer to [the steps to delete the Control Plane](https://docs.tibco.com/emp/platform-cp/1.2.0/doc/html/Default.htm#Installation/uninstalling-tibco-control-plane.htm).

Change the directory to [scripts/eks/](../../scripts/eks) to proceed with the next steps.
```bash
cd scripts/eks
```

> [!NOTE]
> The clean-up script deletes the role created for crossplane, as well.
> You have to set the value of the variable `CP_CROSSPLANE_ROLE` again, if it is unset before running clen-up script.
> Don't set it, if you are using the default value formulated by the script which is in the format
> `${CP_CLUSTER_NAME}-crossplane-${CP_CLUSTER_REGION}`

For the tools charts uninstallation, EFS mount and security groups deletion and cluster deletion, we have provided a helper [clean-up](../../scripts/eks/clean-up-control-plane.sh).
```bash
./clean-up-control-plane.sh
```
