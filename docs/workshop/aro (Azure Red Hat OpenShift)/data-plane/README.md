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
  * [Information needed to be set on Data Plane](#information-needed-to-be-set-on-data-plane)
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
export TP_SERVICE_CIDR="172.30.0.0/16" # Service CIDR: Run the command az aro show -g ${TP_RESOURCE_GROUP} -n ${TP_CLUSTER_NAME} --query networkProfile.serviceCidr -o tsv

## Tooling specific variables
export TP_TIBCO_HELM_CHART_REPO=https://tibcosoftware.github.io/tp-helm-charts # location of charts repo url
export TP_ES_RELEASE_NAME="dp-config-es" # name of dp-config-es release name

## Domain specific variables
export TP_DOMAIN="apps.example.com" # domain to be used for elastic and your data plane

# Storage specific variables
export TP_DISK_STORAGE_CLASS="azure-disk-sc" # name of azure disk storage class
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

If you are using network policies, to ensure that network traffic is allowed from the default ingress namespace to the Data Plane namespace pods, label the namespace by running the following command

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

Run the following command to create a storage class with NFS protocol which uses Azure Files

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
  name: ${TP_DISK_STORAGE_CLASS}
parameters:
  skuName: Premium_LRS # other values: Premium_ZRS, StandardSSD_LRS (default)
provisioner: disk.csi.azure.com
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
EOF
```

We have referred to this disk storage for [Elasticsearch deployment in the section](#install-elastic-stack)

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

You can follow the Elastic/Openshift docs to install OOTB ECK via operator
[deploy-eck-on-openshift](https://www.elastic.co/docs/deploy-manage/deploy/cloud-on-k8s/deploy-eck-on-openshift)

You can use the following command to install the eck-operator via helm, optionally
> [!NOTE]
> Please make sure the service accounts have necessary & sufficient permissions for the elastic-operator to work

```bash
# Install eck-operator
helm upgrade --install --wait --timeout 1h --labels layer=1 --create-namespace -n elastic-system eck-operator eck-operator --repo "https://helm.elastic.co" --version "2.16.0"

# Wait for eck-operator to be installed 
# Verify it by checking the statefulset logs using following command
kubectl logs -n elastic-system sts/elastic-operator
```

**Deployments and Index Creation**

Once the eck-operator is successfully installed, perform the following steps to create
1. Elasticsearch instance
2. deployments and services for Kibana, Elasticsearch, APM
3. index templates
4. index lifecycle policies
5. indices

```bash
# Install dp-config-es
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n elastic-system ${TP_ES_RELEASE_NAME} dp-config-es \
  --labels layer=2 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
domain: ${TP_DOMAIN}
es:
  version: "8.17.3"
  ingress:
    enabled: false
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
    enabled: false
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
    enabled: false
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
The username is normally `elastic`. You can use the following command to get the password.
```bash
kubectl get secret dp-config-es-es-elastic-user -n elastic-system -o jsonpath="{.data.elastic}" | base64 --decode; echo
```

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

**Routes for Elasticsearch, Kibana, APM**

```bash
## Create a passthrough route for Elasticsearch
cat <<EOF | oc apply -n elastic-system -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: elasticsearch-route
spec:
  host: elasticsearch.${TP_DOMAIN} # Override if you don't want the auto-generated host
  tls:
    termination: passthrough
    insecureEdgeTerminationPolicy: Redirect
  to:
    kind: Service
    name: ${TP_ES_RELEASE_NAME}-es-http
EOF

## Create a passthrough route for kibana
cat <<EOF | oc apply -n elastic-system -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: kibana-route
spec:
  host: kibana.${TP_DOMAIN} # Override if you don't want the auto-generated host
  tls:
    termination: passthrough
    insecureEdgeTerminationPolicy: Redirect
  to:
    kind: Service
    name: ${TP_ES_RELEASE_NAME}-kb-http
EOF

## Create a passthrough route for apm-server
cat <<EOF | oc apply -n elastic-system -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: apm-server-route
spec:
  host: apm-server.${TP_DOMAIN} # Override if you don't want the auto-generated host
  tls:
    termination: passthrough
    insecureEdgeTerminationPolicy: Redirect
  to:
    kind: Service
    name: ${TP_ES_RELEASE_NAME}-apm-http
EOF
```

Use the following command to verify successful creation routes
```bash
oc get route -n elastic-system
```

### Configure Prometheus

Prometheus is already installed by default on openshift cluster.

**Enable User Workload Monitoring**
Before creating ServiceMonitors in user namespaces, you need to enable user workload monitoring:

```bash
oc apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |
    enableUserWorkload: true
EOF
```

Wait for the user workload monitoring components to be deployed:

```bash
oc get pods -n openshift-user-workload-monitoring
```

In order to configure prometheus scraping from a data plane, we need to create a ServiceMonitor CR in data plane namespace.

**Use the following command to create ServiceMonitor CR**

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

**Option 1: Long-lived Service Account Token (Recommended)**

For a persistent solution, create a service account with appropriate permissions that provides tokens with extended validity:

1. Create a dedicated service account for Prometheus monitoring:
```bash
oc create sa thanos-client -n openshift-monitoring
```

2. Grant the service account cluster monitoring view permissions:
```bash
oc adm policy add-cluster-role-to-user cluster-monitoring-view -z thanos-client -n openshift-monitoring
```

3. Create a long-lived token for the service account:
```bash
TOKEN=$(oc create token thanos-client -n openshift-monitoring --duration=8760h)  # 1 year duration
```

4. Alternatively, create a token secret for even longer persistence:
```bash
oc apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: thanos-client-token
  namespace: openshift-monitoring
  annotations:
    kubernetes.io/service-account.name: thanos-client
type: kubernetes.io/service-account-token
EOF
```

5. Extract the token from the secret:
```bash
TOKEN=$(oc get secret thanos-client-token -n openshift-monitoring -o jsonpath='{.data.token}' | base64 --decode)
```

6. Get the Thanos Querier route URL:
```bash
HOST=$(oc -n openshift-monitoring get route thanos-querier -ojsonpath='{.status.ingress[].host}')
```

You can then use this long-term token in your data plane configuration:
```bash
"Authorization: Bearer $TOKEN"
```

> [!NOTE]
> - The service account token approach is recommended for production use
> - Tokens created with `oc create token` have configurable durations
> - Secret-based tokens persist until the secret is deleted
> - Store the token securely in your data plane configuration

**Option 2: Short-lived Token (Current User)**

Extract the Thanos-querier API route URL by running the following command:

```bash
HOST=$(oc -n openshift-monitoring get route thanos-querier -ojsonpath='{.status.ingress[].host}')
```

Extract an authentication token to connect to Prometheus by running the following command:

```bash
TOKEN=$(oc whoami -t)
```

You can then use the authorization header on data plane to query using the Thanos querier without username/password
```bash
"Authorization: Bearer $TOKEN"
```

> [!WARNING]
> The above token is a short-lived token and will require frequent rotations on data plane.

**Verify Token Access**

To verify that the token works correctly, test the Prometheus API:
```bash
curl -H "Authorization: Bearer $TOKEN" "https://$HOST/api/v1/query?query=up"
```

**Handling Thanos Router URL with Default /api Endpoint**

When configuring the TIBCO Platform o11y-service to connect to a Thanos Router (or any endpoint that already includes a base /api path), an issue with URL construction may occur. The o11y-service internally appends a path like /api/v1/query to the provided base URL. If your Thanos Router URL already ends with /api, this can result in a malformed path such as .../api/api/v1/query, leading to query failures.

To resolve, ensure that the base URL configured for the Thanos Router in your o11y-service does not include /api if the o11y-service is designed to append it. Provide only the hostname and port, allowing the o11y-service to correctly construct the full path. 
For example, if your Thanos Router is accessible at thanos-router.example.com/api, configure o11y-service with thanos-router.example.com (or equivalent Kubernetes service URL).

## Information needed to be set on Data Plane

You can get BASE_FQDN (fully qualified domain name) by running the command mentioned in [DNS](#dns) section.

| Name | Sample value   | Notes |
|:---------------------|:---------------------------------------------------------------------------------|:--------------------------------------------------------------------------|
| Node CIDR | 10.0.2.0/23  | from Worker Node subnet, please check [TP_WORKER_SUBNET_CIDR in cluster-setup](../cluster-setup/README.md#export-required-variables) |
| Service CIDR  | 172.30.0.0/16   | Run the command `az aro show -g ${TP_RESOURCE_GROUP} -n ${TP_CLUSTER_NAME} --query networkProfile.serviceCidr -o tsv` |
| Pod CIDR  | 10.128.0.0/14         |  Run the command `az aro show -g ${TP_RESOURCE_GROUP} -n ${TP_CLUSTER_NAME} --query networkProfile.podCidr -o tsv` |
| Ingress class name   | openshift-default | used for TIBCO BusinessWorks™ Container Edition |
| Azure Files storage class    | azure-files-sc         | used for TIBCO BusinessWorks™ Container Edition and TIBCO Enterprise Message Service™ (EMS) Azure Files storage  |
| Azure Files storage class    | azure-files-sc-ems        | used for TIBCO Enterprise Message Service™ (EMS)        |
| Azure Disk storage class    | azure-disk-sc        | disk storage can be used for data plane capabilities, in general          |
| BW FQDN   | bwce.\<BASE_FQDN\> | Capability FQDN |
Network Policies Details for Data Plane Namespace | [Data Plane Network Policies Document](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#UserGuide/controlling-traffic-with-network-policies.htm) |

## Clean up

Please delete the Data Plane from TIBCO® Control Plane UI.
Refer to [the steps to delete the Data Plane](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#UserGuide/deleting-data-planes.htm).

Change the directory to [../scripts](../scripts/) to proceed with the next steps.
```bash
cd ../scripts
```

For the tools charts uninstallation, Azure file shares deletion and cluster deletion, we have provided a helper script [clean-up](../scripts/clean-up.sh).

> [!IMPORTANT]
> Please make sure the resources to be deleted are in started/scaled-up state (e.g. ARO cluster)

```bash
./clean-up.sh
```
