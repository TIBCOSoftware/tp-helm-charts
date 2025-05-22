Table of Contents
=================
<!-- TOC -->
* [Table of Contents](#table-of-contents)
* [Azure Red Hat OpenShift (ARO) Creation](#azure-kubernetes-service-cluster-creation)
  * [Introduction](#introduction)
  * [Command Line Tools required](#command-line-tools-required)
  * [Recommended Roles and Permissions](#recommended-roles-and-permissions)
  * [Export Required Variables](#export-required-variables)
  * [Register Resource Providers](#register-resource-providers)
  * [Download Pull Secret](#download-pull-secret)
  * [Pre Cluster Creation Scripts](#pre-cluster-creation-scripts)
  * [Create Azure Red Hat OpenShift (ARO) Cluster](#create-azure-red-hat-openshift-aro-cluster)
  * [Connect to Cluster](#connect-to-cluster)
    * [Get Credentials](#get-credentials)
    * [Connect Using OpenShift CLI](#connect-using-openshift-cli)
    * [Connect Using OpenShift Console](#connect-using-openshift-console)
  * [Create Security Context Constraints](#create-security-context-constraints)
* [Next Steps](#next-steps)
<!-- TOC -->

# Azure Red Hat OpenShift (ARO) Cluster Creation

The goal of this document is to provide hands-on experience to create Microsoft Azure Red Hat OpenShift (ARO) cluster. This is a pre-requisite to deploy TIBCO® Data Plane.

> [!Note]
> This workshop is NOT meant for production deployment.

## Introduction

In order to deploy Data Plane, you need to have a ARO cluster and install the necessary tools. This workshop will guide you to create an ARO cluster and install the necessary tools. After completing the steps from this document, you will need to follow separate steps for [Data Plane](../data-plane/) setups.

## Command Line Tools required

The steps mentioned below were run on a Macbook Pro linux/amd64 platform. The following tools are installed using [brew](https://brew.sh/):
* envsubst (0.22.5, part of homebrew gettext)
* jq (1.7.1)
* yq (v4.44.1)
* bash (5.2.26)
* az (az-cli/2.70.0)
* kubectl (v1.31.5)
* helm (v3.14.3)
* oc (4.18.13)


For reference, [Dockerfile](../../Dockerfile) with [apline 3.20](https://hub.docker.com/_/alpine) can be used to build a docker image with all the tools mentioned above, pre-installed.
The subsequent steps can be followed from within the container.

> [!IMPORTANT]
> Please use --platform while building the image with [docker buildx commands](https://docs.docker.com/engine/reference/commandline/buildx_build/).
> This can be different based on your [machine OS and hardware architecture](https://docs.docker.com/build/building/multi-platform/)

A sample command on Linux AMD64 is
```bash
docker buildx build --platform="linux/amd64" --progress=plain -t workshop-cli-tools:latest --load .
```

## Recommended Roles and Permissions
You will need Contributor and User Access Administrator permissions or Owner permissions, either directly on the virtual network or on the resource group or subscription containing it.

You'll also need sufficient Microsoft Entra permissions (either a member user of the tenant, or a guest assigned with role Application administrator) for the tooling to create an application and service principal on your behalf for the cluster.

Please refer to the documentation to [verify your permissions](https://learn.microsoft.com/en-us/azure/openshift/create-cluster?tabs=azure-cli#verify-your-permissions).

## Export Required Variables

Following variables are required to be set to run the scripts and are referred throughout the document.
Please set/adjust the values of the variables as expected.

> [!NOTE]
> We have used the prefix `TP_` for the required variables.
> It stands for "TIBCO PLATFORM".

> [!IMPORTANT]
> We are using AZ CLI commands to to create the cluster.
> We recommend that you go through the parameters [here](https://learn.microsoft.com/en-us/cli/azure/aro?view=azure-cli-latest#az-aro-create)
> so that it will be easier for you to set the values for the variables below.

```bash
## Azure specific variables
export TP_SUBSCRIPTION_ID=$(az account show --query id -o tsv) # subscription id
export TP_TENANT_ID=$(az account show --query tenantId -o tsv) # tenant id
export TP_AZURE_REGION="eastus" # region of resource group
export TP_RESOURCE_GROUP="openshift-azure"

## Cluster configuration specific variables
export TP_CLUSTER_NAME="aroCluster"
export TP_WORKER_COUNT=6

## Network specific variables
export TP_VNET_NAME="openshiftvnet"
export TP_MASTER_SUBNET_NAME="masterOpenshiftSubnet"
export TP_WORKER_SUBNET_NAME="workerOpenshiftSubnet"
export TP_VNET_CIDR="10.0.0.0/8"
export TP_MASTER_SUBNET_CIDR="10.0.0.0/23"
export TP_WORKER_SUBNET_CIDR="10.0.2.0/23"

## Worker Nodes specific configuration
export TP_WORKER_VM_SIZE="Standard_D8s_v5"
export TP_WORKER_VM_DISK_SIZE_GB="128"
```

> [!IMPORTANT]
> The document uses Azure DNS Service for DNS hosting, resolution.

## Register Resource Providers

Sign into Azure using CLI
```bash
az login
```

Specify the relevant subscription ID
```bash
az account set --subscription ${TP_SUBSCRIPTION_ID}
```

Register the resource providers for
1. Microsoft.RedHatOpenShift
2. Microsoft.Compute
3. Microsoft.Storage
4. Microsoft.Authorization
using the following commands:

```bash
az provider register -n Microsoft.RedHatOpenShift --wait
az provider register -n Microsoft.Compute --wait
az provider register -n Microsoft.Storage --wait
az provider register -n Microsoft.Authorization --wait
```

## Download Pull Secret 

A Red Hat pull secret enables your cluster to access Red Hat container registries, along with other content such as operators from OperatorHub.

Refer to the steps from [Microsoft Documentation to download the pull secret](https://learn.microsoft.com/en-us/azure/openshift/create-cluster?tabs=azure-cli#get-a-red-hat-pull-secret-optional)

Once you log in to your Red Hat account, the pull secret should be available to download at https://console.redhat.com/openshift/install/azure/aro-provisioned

Download the pull secret, copy it in current directory and add executable permission to this file.

```bash
chmod +x pull-secret.txt
```

## Pre Cluster Creation Scripts

pre-aro-cluster-script will create following Azure resources
* Resource group
* Virtual network
* Subnets for
  * ARO cluster master nodes
  * ARO cluster worker nodes

Change the directory to [aro (Azure Red Hat OpenShift)/scripts/](../../aro%20(Azure%20Red%20Hat%20OpenShift)/scripts) to proceed with the next steps.
```bash
cd aro\ \(Azure\ Red\ Hat\ OpenShift\)/scripts
```

> [!IMPORTANT]
> Please make sure that you [export the required vriables](#export-required-variables) before executing the script. 

```bash
./pre-aro-cluster-script.sh
```
It will take approximately 5 minutes to complete the configuration.

## Create Azure Red Hat OpenShift (ARO) Cluster

> [!IMPORTANT]
> Please make sure that you [export the required vriables](#export-required-variables) before executing the script
> and you pass the pull-secret.txt downloaded above

Run the following command
```bash
az aro create \
  --resource-group ${TP_RESOURCE_GROUP} \
  --name ${TP_CLUSTER_NAME} \
  --vnet ${TP_VNET_NAME} \
  --master-subnet ${TP_MASTER_SUBNET_NAME} \
  --worker-subnet ${TP_WORKER_SUBNET_NAME} \
  --worker-count ${TP_WORKER_COUNT} \
  --worker-vm-disk-size-gb ${TP_WORKER_VM_DISK_SIZE_GB} \
  --worker-vm-size ${TP_WORKER_VM_SIZE} \
  --pull-secret @pull-secret.txt
```

It will take approximately 30 to 45 minutes to create an ARO cluster.

## Connect to Cluster

### Get Credentials
We can use the following command to list the credentials.
```bash
az aro list-credentials --name ${TP_CLUSTER_NAME} --resource-group ${TP_RESOURCE_GROUP}
```
You will get the kubeadminUsername & kubeadminPassword from the above command.

### Connect Using OpenShift CLI
Run the following command to get the API Server endpoint

```bash
apiServer=$(az aro show -g ${TP_RESOURCE_GROUP} -n ${TP_CLUSTER_NAME} --query apiserverProfile.url -o tsv)
```

Use the following command to connect
```bash
oc login ${apiServer} -u <kubeadminUsername> -p <kubeadminPassword>
```

### Connect Using OpenShift Console

Run the following command to get the cluster console URL

```bash
az aro show --name ${TP_CLUSTER_NAME} --resource-group ${TP_RESOURCE_GROUP} --query "consoleProfile.url" -o tsv
```
Launch the console URL in a browser and login using the kubeadmin credentials obtained above.

## Create Security Context Constraints

Security Context Constraints (SCCs) can be used to control permissions for pods. These permissions include actions that a pod can perform and what resources it can access. You can use SCCs to define a set of conditions that a pod must run with to be accepted into the system.

By default following SCCs are available:
anyuid
hostaccess
hostmount-anyuid
hostnetwork
hostnetwork-v2
machine-api-termination-handler
node-exporter
nonroot
nonroot-v2 
privileged
privileged-genevalogging
restricted
restricted-v2

In addition, we propose creating a new SCC which is similar to anyuid but differs for NET_BIND_SERVICE capabilities (CAPS).

```bash
oc apply -f - <<EOF
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  annotations:
    kubernetes.io/description: tp-scc provides all features of the restricted SCC but allows users to run with any UID and any GID.
  name: tp-scc
priority: 10
allowHostDirVolumePlugin: false
allowHostIPC: false
allowHostNetwork: false
allowHostPID: false
allowHostPorts: false
allowPrivilegeEscalation: false
allowPrivilegedContainer: false
allowedCapabilities:
- NET_BIND_SERVICE
defaultAddCapabilities: null
fsGroup:
  type: RunAsAny
groups: []
readOnlyRootFilesystem: false
requiredDropCapabilities:
- ALL
runAsUser:
  type: RunAsAny
seLinuxContext:
  type: MustRunAs
seccompProfiles:
- runtime/default
supplementalGroups:
  type: RunAsAny
users: []
volumes:
- configMap
- csi
- downwardAPI
- emptyDir
- ephemeral
- persistentVolumeClaim
- projected
- secret
EOF
```

To verify that the SCC is created, run the following command:

```bash
oc get scc tp-scc
```

# Next Steps
For Data Plane, follow the steps from [Data Plane README](../data-plane/README.md)


