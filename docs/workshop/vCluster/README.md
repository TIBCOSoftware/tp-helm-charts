Table of Contents
=================
<!-- TOC -->
* [Table of Contents](#table-of-contents)
* [vCluster Workshop README](#vcluster-workshop-readme)
  * [What is vCluster](#what-is-vcluster)
    * [Prerequisites for vCluster](#prerequisites)
  * [Steps to install a vCluster in existing EKS cluster](#steps-to-install-a-vcluster-in-existing-eks-cluster)
    * [Export required variables](#export-required-variables)
    * [Create a CP vCluster](#cp-cluster-creation)
      * [Connect to the CP vCluster](#verify-if-the-cp-vcluster-is-running)
      * [Install Host Path Mapper chart](#install-hostpath-mapper-chart)
  * [TIBCO® Control Plane Deployment](#tibco-control-plane-deployment)
    * [Prerequisite for installing Control Plane](#prerequisites-1)
  * [Data Plane deployment in vCluster](#steps-to-install-dp-in-vcluster)
    * [Export required variables](#export-required-variables-1)
    * [Create a DP vCluster](#dp-cluster-creation)
      * [Connect to the DP vCluster](#verify-if-the-dp-vcluster-is-running)
      * [Install Host Path Mapper chart](#install-hostpath-mapper-chart-1)
  * [Clean up](#clean-up)
    * [Clean up of CP resources](#clean-up-of-cp-vcluster)
    * [Clean up of DP resources](#clean-up-of-dp-vcluster)
<!-- TOC -->

# vCluster Workshop README

This document provides a step-by-step guide to installing and configuring vCluster, a lightweight, isolated, and scalable Kubernetes environment that runs on top of an existing Kubernetes cluster. The workshop also covers the deployment of CP (Control Plane) and DP (Data Plane) components.

---
## What is vCluster?
vCluster is a virtual cluster that runs on top of an existing Kubernetes cluster. It provides a separate control plane for each virtual cluster, allowing multiple teams or users to have their own Kubernetes environment without the need to manage and maintain a separate physical cluster. Please refer to the [vCluster documentation](https://www.vcluster.com/docs/vcluster/introduction/what-are-virtual-clusters) for more information.

> [!NOTE]
> For installing vCluster, the vCluster chart or cli will create clusterRole and clusterRole binding based on the resources to be synced between the host cluster and virtual cluster. Please refer [vCluster github chart values](https://github.com/loft-sh/vcluster/blob/main/chart/templates/clusterrole.yaml)

---
## Prerequisites
Before starting the workshop, make sure you have the following prerequisites:

- An existing Kubernetes cluster (e.g. EKS, GKE, AKS)
  - User must have access to create a namespace and deploy applications to it.
- Required third-party tools installed (e.g. external-dns, ingress-controller, aws-lb-controller, elastic-search, EFS SC, postgres RDS, Prometheus) in the host K8s cluster
- `kubectl` installed and configured to connect to your Kubernetes cluster
- Helm v3.10.0+ is required
- vCluster CLI installed (GA version v0.22 )
  - Refer to this [installation guide](https://www.vcluster.com/docs/vcluster#deploy-vcluster) for installation of vCluster CLI.

> [!NOTE]
> This workshop has been certified and validated using vcluster chart version v0.22 and hostpathmapper chart version v0.2.0, ensuring that all instructions and commands are accurate and fully compatible.

---
## Steps to install a vCluster in existing EKS cluster

In this step we will deploy a vCluster instance named cp-vcluster to the cp-vcluster namespace. This instance will provide a isolated and scalable Kubernetes environment for our CP components in the existing EKS cluster. Before proceeding with the above steps, ensure that you have an IAM role configured with the necessary SES permissions for sending emails. This IAM role will be used by the CP cluster to send emails.

> [!IMPORTANT]
> Update the cp-cluster.yaml file with the ARN of this IAM role to grant the required permissions.

### Export required variables
Following variables are required to be set to run the commands for vCluster.
Please set/adjust the values of the variables as expected.

> [!NOTE]
> We have used the prefix `TP_` for the required variables.
> It stands for "TIBCO PLATFORM".

```bash
## vCluster configuration specific variables
export TP_CP_VCLUSTER_NAMESPACE="cp-vcluster" # namespace name in host cluster where vCluster will be created
export TP_CP_VCLUSTER_NAME="cp-vcluster" # vCluster name
```

### CP cluster creation 

To begin, create a namespace in the host cluster that will host the vCluster instance.
``` 
kubectl create namespace ${TP_CP_VCLUSTER_NAMESPACE}
```

For creation of the CP vCluster we are going to use cutomised values *(cp-cluster.yaml)* as we need to enable extra syncers for our use-case. Please have a look at the [vCluster helm chart value](https://github.com/loft-sh/vcluster/blob/v0.22/chart/values.yaml) for detailed information.
```
helm upgrade --install ${TP_CP_VCLUSTER_NAME} vcluster \
    --values cp-cluster.yaml \
    --repo https://charts.loft.sh \
    --namespace ${TP_CP_VCLUSTER_NAMESPACE} \
    --repository-config='' \
    --version v0.22.4
```

### Verify if the CP vCluster is running
Here vCluster installation will create a new context that starts with *"vcluster_cp-vcluster"* and updates the kubeconfig file to point to that context.
   - Execute ``` vcluster connect ${TP_CP_VCLUSTER_NAME} ``` to connect to your vCluster context.
   - Execute ``` vcluster disconnect ``` to switch back to your default (host) context.

### Install hostPath mapper chart
In addition to enable the hostPath mapping we need to install the [vcluster-hostpath-mapper helm chart](https://www.vcluster.com/docs/v0.19/o11y/logging/hpm) in namespace where vCluster is deployed. This is required only for fluenbit.
```
helm install vcluster-hostpath-mapper vcluster-hpm \
    --repo https://charts.loft.sh \
    -n ${TP_CP_VCLUSTER_NAMESPACE} \
    --set VclusterReleaseName=${TP_CP_VCLUSTER_NAME} \
    --version=0.2.0
``` 

## TIBCO® Control Plane Deployment

### Prerequisites
Make sure that the CP vCluster is running and you are connected to it.
   - Execute ``` vcluster connect ${TP_CP_VCLUSTER_NAME} ``` to connect to your vCluster context.
Before installing Platform Bootstrap Chart we need to install [cert-manager](https://cert-manager.io/docs/installation/helm/#installing-cert-manager) (required by router, resource-set operator, hybrid-proxy) & [k8s metrics-server chart](https://github.com/kubernetes-sigs/metrics-server?tab=readme-ov-file#installation) in the virtual cluster.

To install TIBCO® Control Plane in this vCluster, refer to the steps outlined in the [EKS Deployment Guide](../eks/control-plane/README.md), and proceed with the installation of the Platform Bootstrap and Platform Base charts as described.

---
## Steps to install DP in vCluster

In this step we will deploy a vCluster instance named dp-vcluster to the dp-vcluster namespace. This instance will provide a isolated and scalable Kubernetes environment for our DP components.

### Export required variables
Following variables are required to be set to run the commands for vCluster.
Please set/adjust the values of the variables as expected.

> [!NOTE]
> We have used the prefix `TP_` for the required variables.
> It stands for "TIBCO PLATFORM".

```bash
## vCluster configuration specific variables
export TP_DP_VCLUSTER_NAMESPACE="dp-vcluster" # namespace name in host cluster where vCluster will be created
export TP_DP_VCLUSTER_NAME="dp-vcluster" # vCluster name
```

### DP cluster creation 

To begin, create a namespace in the host cluster that will host the vCluster instance.
``` 
kubectl create namespace ${TP_DP_VCLUSTER_NAMESPACE}
```

For creation of the DP vCluster we are going to use cutomised values *(dp-cluster.yaml)* as we need to enable extra syncers for our use-case. Please have a look at the [vCluster helm chart value](https://github.com/loft-sh/vcluster/blob/v0.22/chart/values.yaml) for detailed information.
```
helm upgrade --install ${TP_DP_VCLUSTER_NAME} vcluster \
    --values dp-cluster.yaml \
    --repo https://charts.loft.sh \
    --namespace ${TP_DP_VCLUSTER_NAMESPACE} \
    --repository-config='' \
    --version v0.22.4
```

### Verify if the DP vCluster is running
Here vCluster installation will create a new context that starts with "vcluster_dp-vcluster" and updates the kubeconfig file to point to that context.
   - Execute ``` vcluster connect ${TP_DP_VCLUSTER_NAME} ``` to connect to your vCluster context.
   - Execute ``` vcluster disconnect ``` to switch back to your default (host) context.

### Install hostPath mapper chart
In addition to enable the hostPath mapping we need to install the [vcluster-hostpath-mapper helm chart](https://www.vcluster.com/docs/v0.19/o11y/logging/hpm) in namespace where vCluster is deployed. This is required only for fluenbit.
```
helm install vcluster-hostpath-mapper vcluster-hpm \
    --repo https://charts.loft.sh \
    -n ${TP_DP_VCLUSTER_NAMESPACE} \
    --set VclusterReleaseName=${TP_DP_VCLUSTER_NAME} \
    --version=0.2.0
``` 

### Install Kubernetes Metrics Server chart
To deploy the Kubernetes metrics server in your virtual cluster, please follow the installation instructions outlined in the [k8s metrics-server chart](https://github.com/kubernetes-sigs/metrics-server?tab=readme-ov-file#installation) on GitHub.

### Install DP in vCluster

Connect to the DP vCluster and execute the DP registeration commands.


## Clean-up

### Clean-up of CP vCluster

Run the following commands in the host cluster to clean up the CP resources

> [!NOTE]
> Make sure to replace the variables with the actual values used during the workshop.

```
# Delete the vCluster 
vcluster delete ${TP_CP_VCLUSTER_NAME} -n ${TP_CP_VCLUSTER_NAMESPACE}

# Uninstall the HPM chart
helm uninstall vcluster-hostpath-mapper -n ${TP_CP_VCLUSTER_NAMESPACE}

# Delete the namespace from the host cluster
kubectl delete namespace ${TP_CP_VCLUSTER_NAMESPACE}
```

### Clean-up of DP vCluster

Run the following commands in the host cluster to clean up the DP resources

> [!NOTE]
> Make sure to replace the variables with the actual values used during the workshop.

```
# Delete the vCluster 
vcluster delete ${TP_DP_VCLUSTER_NAME} -n ${TP_DP_VCLUSTER_NAMESPACE}

# Uninstall the HPM chart
helm uninstall vcluster-hostpath-mapper -n ${TP_DP_VCLUSTER_NAMESPACE}

# Delete the namespace from the host cluster
kubectl delete namespace ${TP_DP_VCLUSTER_NAMESPACE}
```