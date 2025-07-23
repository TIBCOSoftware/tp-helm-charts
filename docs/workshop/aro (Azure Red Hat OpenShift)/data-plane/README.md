Table of Contents
=================
<!-- TOC -->
* [Table of Contents](#table-of-contents)
* [Data Plane Cluster Workshop](#data-plane-cluster-workshop)
  * [Export Required Variables](#export-required-variables)
  * [Ingress Controller, DNS](#ingress-controller--dns)
  * [Install Storage class](#install-storage-class)
  * [Regarding Data Plane Namespace and Service Accounts](#regarding-data-plane-namespace-and-service-accounts)
  * [Install / Configure Observability tools](#install--configure-observability-tools)
    * [Install Elastic stack](#install-elastic-stack)
    * [Configure Prometheus](#configure-prometheus)
  * [Information needed to be set on TIBCO® Data Plane](#information-needed-to-be-set-on-tibco-data-plane)
  * [Clean up](#clean-up)
<!-- TOC -->

# Data Plane Cluster Workshop

The goal of this workshop is to provide hands-on experience to prepare Azure Red Hat Openshift (ARO) cluster to be used as a Data Plane. In order to deploy Data Plane, you need to have some necessary tools installed. This workshop will guide you to install/use the necessary tools.

> [!IMPORTANT]
> This workshop is NOT meant for production deployment.

To perform the steps mentioned in this workshop document, it is assumed you already have an ARO cluster created and can connect to it.

> [!IMPORTANT]
> To create ARO cluster and connect to it, please refer [steps for ARO cluster creation](../cluster-setup/README.md#connect-to-cluster)

Additionally, you should have at least the following permissions on the ARO:
1. create security context config
2. create storage classes
3. deploy helm charts
4. create projects (namespaces)
5. create service accounts
6. add security context config to the service accounts (user)
7. create service monitors in namespace
8. deploy operators from operator hub (if applicable)


## Export Required Variables

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
export TP_RESOURCE_GROUP="openshift-azure" # set the resource group name in which all resources will be deployed

## Cluster configuration specific variables
export TP_CLUSTER_NAME="aroCluster"

## Network specific variables
export TP_SERVICE_CIDR="10.0.0.0/16" # CIDR for service cluster IPs

## Helm chart repo
export TP_TIBCO_HELM_CHART_REPO=https://tibcosoftware.github.io/tp-helm-charts # location of charts repo url

```

## Ingress Controller & DNS

### Ingress Controller
For the purpose of this data plane workshop, we are using the default ingress controller available with the ARO cluster.
Please refer to [ARO Ingress Operator](https://docs.redhat.com/en/documentation/openshift_container_platform/4.15/html/networking/configuring-ingress#nw-ne-openshift-ingress_configuring-ingress)

Use the following command to get the ingress class name.
```bash
oc get ingressclass -A
NAME                            CONTROLLER                                                     PARAMETERS                                        AGE
openshift-default               openshift.io/ingress-to-route                                  IngressController.operator.openshift.io/default   39d
```

If you are using network policies, to ensure that network traffic is allowed from the default ingress namespace to the Data Plane namespace pods, label the namespace running following command

```bash
oc label namespace openshift-ingress networking.platform.tibco.com/non-dp-ns=enable --overwrite=true
```

### DNS
For the purpose of this data plane workshop, we are using default DNS provisioned for ARO cluster. The base DNS of this can be found using the following command

```bash
oc get ingresscontroller -n openshift-ingress-operator default -o json | jq -r '.status.domain'
```
It should be something like "apps.<random_alphanumeric_string>.${TP_AZURE_REGION}.aroapp.io"

## Install Storage class

You will require the storage classes for capabilities deployment.

Run the following command to create a storage class which uses Azure Files (Persistent Volumes will be created as fileshares).
```bash
oc apply -f - <<EOF
apiVersion: storage.k8s.io/v1
allowVolumeExpansion: true
kind: StorageClass
metadata:
  name: azure-files-sc
mountOptions:
- mfsymlinks
- cache=strict
- nosharesock
parameters:
  allowBlobPublicAccess: "false"
  networkEndpointType: privateEndpoint
  skuName: Premium_LRS
provisioner: file.csi.azure.com
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF
```

Similar to above, for TIBCO Enterprise Message Service™ (EMS) capability, you will need to create one of the following two storage classes:

Run the following command to create a storage class with nfs protocol which uses Azure Files

```bash
oc apply -f - <<EOF
apiVersion: storage.k8s.io/v1
allowVolumeExpansion: true
kind: StorageClass
metadata:
  name: azure-files-sc-ems
mountOptions:
- soft
- timeo=300
- actimeo=1
- retrans=2
- _netdev
parameters:
  allowBlobPublicAccess: "false"
  networkEndpointType: privateEndpoint
  protocol: nfs
  skuName: Premium_LRS
provisioner: file.csi.azure.com
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF
```

Alternatively, run the following command to create a storage class with Azure Disks

```bash
oc apply -f - <<EOF
apiVersion: storage.k8s.io/v1
allowVolumeExpansion: true
kind: StorageClass
metadata:
  name: azure-disk-sc
parameters:
  skuName: Premium_LRS # other values: Premium_ZRS, StandardSSD_LRS (default)
provisioner: disk.csi.azure.com
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
EOF
```

## Regarding Data Plane Namespace and Service Accounts
Before creating the Data Plane, ensure that the service accounts in the Data Plane namespace have been granted permission to use the Security Context Constraints (SCC) defined in the [cluster setup README](../cluster-setup/README.md#create-security-context-constraints)

This step is essential to ensure that Data Plane pods can be created and run properly in the cluster.

```bash
export DP_NAMESPACE="ns" # Replace with your Data Plane namespace
export DP_SERVICE_ACCOUNT="sa" # Replace with your Data Plane service account
oc adm policy add-scc-to-user tp-scc system:serviceaccount:${DP_NAMESPACE}:${DP_SERVICE_ACCOUNT}
oc adm policy add-scc-to-user tp-scc system:serviceaccount:${DP_NAMESPACE}:default
```

## Install / Configure Observability tools

### Install Elastic stack

You can follow the Elastic/Openshift docs to install ECK via operator
[deploy-eck-on-openshift](https://www.elastic.co/docs/deploy-manage/deploy/cloud-on-k8s/deploy-eck-on-openshift)

### Configure Prometheus

Prometheus is already installed by default on openshift cluster.
In order to configure prometheus scraping from a data plane, we need to create a ServiceMonitor CR in data plane namespace.

<summary>Use the following command to create ServiceMonitor CR</summary>

```bash
export DP_NAMESPACE="ns" # Replace with your Data Plane namespace

kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: otel-collector-monitor
  namespace: ${DP_NAMESPACE}
spec:
  endpoints:
  - interval: 30s
    path: /metrics
    port: prometheus
    scheme: http
  jobLabel: otel-collector
  selector:
    matchLabels:
      app.kubernetes.io/name: otel-userapp-metrics
EOF
```

> [!NOTE]
> Please create the above ServiceMonitor for all DP namespaces 


To configure a prometheus query on data plane Monitoring, Openshift doesn't have username/password support by default.
In order to configure the query, we can use a token

[accessing-metrics-from-outside-cluster_accessing-monitoring-apis-by-using-the-cli](https://docs.redhat.com/en/documentation/openshift_container_platform/4.17/html/monitoring/accessing-metrics#accessing-metrics-from-outside-cluster_accessing-monitoring-apis-by-using-the-cli )

Extract the thanos-querier API route URL by running the following command:

```bash
HOST=$(oc -n openshift-monitoring get route thanos-querier -ojsonpath='{.status.ingress[].host}')
```

Extract an authentication token to connect to Prometheus by running the following command:

```bash
TOKEN=$(oc whoami -t)
```

you can then use the authorization header on data plane to query using the thanos querier without username/password
```bash
"Authorization: Bearer $TOKEN"
```

The above token is a short lived token and will require frequent rotations on data plane.
For a more persistent solution, create a service account with appropriate permissions that provides tokens with extended validity:

```bash
oc create sa thanos-client -n openshift-monitoring 
oc adm policy add-cluster-role-to-user cluster-monitoring-view -z thanos-client -n openshift-monitoring
TOKEN=$(oc create token thanos-client -n openshift-monitoring)
```

you can then use the authorization header on data plane to query using the thanos querier without username/password
```bash
"Authorization: Bearer $TOKEN"
```


## Information needed to be set on TIBCO® Data Plane

You can get BASE_FQDN (fully qualified domain name) by running the command mentioned in [DNS](#dns) section.

| Name                 | Sample value                                                                     | Notes                                                                     |
|:---------------------|:---------------------------------------------------------------------------------|:--------------------------------------------------------------------------|
| Node CIDR             | 10.0.2.0/23                                                                    | from Worker Node subnet Check [TP_WORKER_SUBNET_CIDR in cluster-setup](../cluster-setup/README.md#export-required-variables)                                      |
| Service CIDR             | 172.30.0.0/16                                                                    | Run the command az aro show -g ${TP_RESOURCE_GROUP} -n ${TP_CLUSTER_NAME} --query networkProfile.serviceCidr -o tsv                                        |
| Pod CIDR             | 10.128.0.0/14                                                                    |  Run the command az aro show -g ${TP_RESOURCE_GROUP} -n ${TP_CLUSTER_NAME} --query networkProfile.podCidr -o tsv                                        |
| Ingress class name   | openshift-default                                                                            | used for TIBCO BusinessWorks™ Container Edition                                                     |
| Azure Files storage class    | azure-files-sc                                                                           | used for TIBCO BusinessWorks™ Container Edition and TIBCO Enterprise Message Service™ (EMS) Azure Files storage                                         |
| Azure Files storage class    | azure-files-sc-ems                                                                          | used for TIBCO Enterprise Message Service™ (EMS)                                             |
| Azure Disk storage class    | azure-disk-sc                                                                          | disk storage can be used for data plane capabilities, in general                                               |
| BW FQDN              | bwce.\<BASE_FQDN\>                                                               | Capability FQDN |
Network Policies Details for Data Plane Namespace | [Data Plane Network Policies Document](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#UserGuide/controlling-traffic-with-network-policies.htm) |

## Clean up

Please delete the Data Plane from TIBCO® Control Plane UI.
Refer to [the steps to delete the Data Plane](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#UserGuide/deleting-data-planes.htm).

Change the directory to [../scripts](../scripts/) to proceed with the next steps.
```bash
cd ../scripts
```

For the tools charts uninstallation, Azure file shares deletion and cluster deletion, we have provided a helper [clean-up](../scripts/clean-up.sh).

> [!IMPORTANT]
> Please make sure the resources to be deleted are in started/scaled-up state (e.g. ARO cluster)

```bash
./clean-up.sh
```
