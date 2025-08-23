Table of Contents
=================
<!-- TOC -->
* [Table of Contents](#table-of-contents)
* [TIBCO® Control Plane Cluster Workshop](#tibco-control-plane-aro-workshop)
  * [Export required variables](#export-required-variables)
  * [Ingress Controller, Storage classes](#ingress-controller-storage-classes)
    * [Configure Default Ingress Controller](#configure-default-ingress-controller)
    * [Install Storage Classes](#install-storage-classes)
  * [Install Postgres](#install-postgres)
* [TIBCO® Control Plane Deployment](#tibco-control-plane-deployment)
  * [Pre-requisites to create namespace and service account](#pre-requisites-to-create-namespace-and-service-account)
  * [Configure Certificates, DNS records](#configure-certificates-dns-records)
    * [Certificate and Secret for MY Domain](#certificate-and-secret-for-my-domain)
    * [Certificate and Secret for TUNNEL Domain](#certificate-and-secret-for-tunnel-domain)
  * [Information needed to be set on TIBCO® Control Plane](#information-needed-to-be-set-on-tibco-control-plane)
  * [Export additional variables required for chart values](#export-additional-variables-required-for-chart-values)
  * [Generate and Create session-keys Secret (Required for Router Pods)](#generate-and-create-session-keys-secret-required-for-router-pods)
  * [Bootstrap Chart values](#bootstrap-chart-values)
  * [Next Steps](#next-steps)
* [Clean-up](#clean-up)
<!-- TOC -->

# TIBCO® Control Plane ARO Cluster Workshop

The goal of this workshop is to provide hands-on experience to prepare Azure Red Hat Openshift (ARO) cluster to be used as a Control Plane. In order to deploy Control Plane, you need to have some necessary tools installed. This workshop will guide you to install/use the necessary tools.

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
> We have used the prefixes `TP_` and `CP_` for the required variables.
> These prefixes stand for "TIBCO PLATFORM" and "Control Plane" respectively.

```bash
## Azure specific variables
export TP_SUBSCRIPTION_ID=$(az account show --query id -o tsv) # subscription id
export TP_TENANT_ID=$(az account show --query tenantId -o tsv) # tenant id
export TP_AZURE_REGION="eastus" # region of resource group
export TP_RESOURCE_GROUP="openshift-azure" # set the resource group name in which all resources will be deployed

## Cluster configuration specific variables
export TP_CLUSTER_NAME="aroCluster"

## Network specific variables
export TP_NODE_CIDR="10.0.2.0/23" # Node CIDR, you can get it from Worker Node subnet in cluster-setup/README.md under the section export-required-variables
export TP_POD_CIDR="10.128.0.0/14" # Pod CIDR: Run the command az aro show -g ${TP_RESOURCE_GROUP} -n ${TP_CLUSTER_NAME} --query networkProfile.podCidr -o tsv
export TP_SERVICE_CIDR="172.30.0.0/16" # Service CIDR: Run the command az aro show -g ${TP_RESOURCE_GROUP} -n ${TP_CLUSTER_NAME} --query networkProfile.serviceCidr -o tsv

## Helm chart repo
export TP_TIBCO_HELM_CHART_REPO=https://tibcosoftware.github.io/tp-helm-charts # location of charts repo url

## Domain specific variables
export TP_CLUSTER_DOMAIN="aro.example.com" # replace it with your DNS Zone name
export TP_DNS_RESOURCE_GROUP=""  # replace with name of resource group containing dns record sets
export TP_TOP_LEVEL_DOMAIN="${TP_CLUSTER_DOMAIN}" # top level domain of TP_DOMAIN
export TP_SANDBOX="apps" # hostname of TP_DOMAIN
export TP_DOMAIN="${TP_SANDBOX}.${TP_TOP_LEVEL_DOMAIN}" # domain to be used
export TP_INGRESS_CLASS="openshift-default" # name of main ingress class used by capabilities, use 'traefik'

# Storage specific variables
export TP_DISK_STORAGE_CLASS="azure-disk-sc" # name of azure disk storage class
export TP_FILE_STORAGE_CLASS="azure-files-sc" # name of azure files storage class

# Network policy specific variables
export TP_ENABLE_NETWORK_POLICY="true" # possible values "true", "false"

# LogServer specific variables
export TP_LOGSERVER_ENDPOINT=""
export TP_LOGSERVER_INDEX="" # logserver index to push the logs to
export TP_LOGSERVER_USERNAME=""
export TP_LOGSERVER_PASSWORD=""
```

> [!IMPORTANT]
> We are assuming, customer will be using the Azure DNS Service

## Ingress Controller, Storage classes

In this section, we will modify the default OOTB ingress controller of ARO and create storage classes. 
It will create the following resources:
* ingress controller which will be able to manage wildcard domains
* storage class for Azure Disks
* storage class for Azure Files

### Configure Default Ingress Controller

> [!NOTE]
> For the purpose of this Control Plane workshop, we are using default Ingress Controller provisioned for ARO cluster.

If you are using a custom cluster domain following the steps [Regarding Custom Cluster Domain](../cluster-setup/README.md#regarding-custom-cluster-domain) and [Configure API Server and Ingress Router with Custom Domain Certificates](../cluster-setup/README.md#configure-api-server-and-ingress-router-with-custom-domain-certificates), please make sure you configure the default ingress controller to allow wildcard domains and internamespace ownership.

Please refer [the document for the route admission spec](https://docs.redhat.com/en/documentation/openshift_container_platform/4.19/html/operator_apis/ingresscontroller-operator-openshift-io-v1#spec-routeadmission) for more information.

This is a required step since we use wildcard domains for `my` and `tunnel` domains and create the ingresses in Control Plane namespaces.

Run the following command to patch the default ingress controller.
```bash
oc -n openshift-ingress-operator patch ingresscontroller/default --type='merge' \
  -p '{"spec":{"routeAdmission":{"wildcardPolicy":"WildcardsAllowed","namespaceOwnership":"InterNamespaceAllowed"}}}'
```

Alternatively, you can create a new ingress controller and use the corresponding ingress class for Control Plane ingresses.

### Install Storage Classes

You will require the storage classes for Control Plane deployment.

Run the following command to create a storage class which uses Azure Files (Persistent Volumes will be created as fileshares).
```bash
oc apply -f - <<EOF
apiVersion: storage.k8s.io/v1
allowVolumeExpansion: true
kind: StorageClass
metadata:
  name: ${TP_FILE_STORAGE_CLASS}
mountOptions:
- mfsymlinks
- cache=strict
- nosharesock
- noperm
parameters:
  allowBlobPublicAccess: "false"
  networkEndpointType: privateEndpoint
  skuName: Premium_LRS
provisioner: file.csi.azure.com
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF
```

Additionally, run the following command to create a storage class with Azure Disks which can be used for Postgres

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

## Install Postgres

In this section, we will install postgres server chart. We have made a helm chart called `on-premises-third-party` that encapsulates the installation of postgres server.

You can optionally use any pre-existing postgres installation, but please make sure that the Control Plane pods can communicate with that database.

```bash
export TP_CONTAINER_REGISTRY_URL="csgprduswrepoedge.jfrog.io" # jfrog edge node url us-west-2 region, replace with container registry url as per your deployment region
export TP_CONTAINER_REGISTRY_USER="" # replace with your container registry username
export TP_CONTAINER_REGISTRY_PASSWORD="" # replace with your container registry password
export TP_CONTAINER_REGISTRY_REPOSITORY="tibco-platform-docker-prod" # replace with your container registry repository

helm upgrade --install --wait --timeout 1h --create-namespace \
  -n tibco-ext postgresql on-premises-third-party \
  --labels layer=2 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
global:
  tibco:
    containerRegistry:
      url: "${TP_CONTAINER_REGISTRY_URL}"
      username: "${TP_CONTAINER_REGISTRY_USER}"
      password: "${TP_CONTAINER_REGISTRY_PASSWORD}"
      repository: "${TP_CONTAINER_REGISTRY_REPOSITORY}"
  storageClass: ${TP_DISK_STORAGE_CLASS}
postgresql:
  enabled: true
  auth:
    postgresPassword: postgres
    username: postgres
    password: postgres
    database: "postgres"
  image:
    registry: "${TP_CONTAINER_REGISTRY_URL}"
    repository: ${TP_CONTAINER_REGISTRY_REPOSITORY}/common-postgresql
    tag: 16.4.0-debian-12-r14
    pullSecrets:
    - tibco-container-registry-credentials
    debug: true
  primary:
    # resourcesPreset: "nano" # nano micro small
    resources:
      requests:
        cpu: 250m
        memory: 256Mi
EOF
```

If you are using network policies, to ensure that network traffic is allowed from the tibco-ext namespace to the Control Plane namespace pods, label this namespace by running following command

```bash
oc label namespace tibco-ext networking.platform.tibco.com/non-cp-ns=enable --overwrite=true
```

> [!IMPORTANT]
> Please note that the Postgres installed above does not enforce SSL, by default. It has to be manually configured.
> To enforce SSL while to connecting to the instance, please configure the tls values for the above chart


# TIBCO® Control Plane Deployment

## Pre-requisites to create namespace and service account

We will be creating a namespace where the TIBCO Control Plane charts will be deployed.

```bash

export CP_INSTANCE_ID="cp1" # unique id to identify multiple cp installation in same cluster (alphanumeric string of max 5 chars)

oc apply -f <(envsubst '${CP_INSTANCE_ID}' <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
 name: ${CP_INSTANCE_ID}-ns
 labels:
  platform.tibco.com/controlplane-instance-id: ${CP_INSTANCE_ID}
EOF
)
```

Create a service account in the namespace. This service account is used for TIBCO Control Plane deployment.

```bash
oc create serviceaccount ${CP_INSTANCE_ID}-sa -n ${CP_INSTANCE_ID}-ns
```

Please ensure that the service accounts for the Control Plane namespace have been granted permission to use the Security Context Constraints (SCC) defined in the [cluster setup README](../cluster-setup/README.md#create-security-context-constraints)

This step is essential to ensure that Control Plane pods can be created and run properly in the cluster.

```bash
oc adm policy add-scc-to-user tp-scc system:serviceaccount:${CP_INSTANCE_ID}-ns:${CP_INSTANCE_ID}-sa
oc adm policy add-scc-to-user tp-scc system:serviceaccount:${CP_INSTANCE_ID}-ns:default
```

## Configure Certificates, DNS records 

> [!IMPORTANT]
> For the scope of this document, we use Azure DNS Service for DNS hosting, resolution.

We recommend that you use different DNS records and certificates for `my` (Control Plane application) and `tunnel` (hybrid connectivity) domains. You can use wildcard domain names for these Control Plane application and hybrid connectivity domains. The certificates for both the domains are created [using certbot commands](https://eff-certbot.readthedocs.io/en/stable/using.html#certbot-commands)

We recommend that you use different `CP_INSTANCE_ID` to distinguish multiple Control Plane installations within a cluster.

`TP_DOMAIN` is exported as part of [Export required variables](#export-required-variables)

Please export below variables and values related to domains:
```bash
## Domains
export CP_INSTANCE_ID="cp1" # unique id to identify multiple cp installation in same cluster (alphanumeric string of max 5 chars)
export CP_MY_DNS_DOMAIN=${CP_INSTANCE_ID}-my.${TP_DOMAIN} # domain to be used
export CP_TUNNEL_DNS_DOMAIN=${CP_INSTANCE_ID}-tunnel.${TP_DOMAIN} # domain to be used
export EMAIL="" # for certificates
```

If you are using network policies, to ensure that network traffic is allowed from the default ingress namespace to the Control Plane namespace pods, label the namespace running following command

```bash
oc label namespace openshift-ingress networking.platform.tibco.com/non-cp-ns=enable --overwrite=true
```

### Certificate and Secret for MY Domain

```bash
export SCRATCH_DIR="/tmp/${CP_INSTANCE_ID}-my"

certbot certonly --manual \
  --preferred-challenges=dns \
  --email ${EMAIL} \
  --server https://acme-v02.api.letsencrypt.org/directory \
  --agree-tos \
  -d "*.${CP_MY_DNS_DOMAIN}" \
  --config-dir "${SCRATCH_DIR}/config" \
  --work-dir "${SCRATCH_DIR}/work" \
  --logs-dir "${SCRATCH_DIR}/logs"
```

Do not interrupt the command.
Create the _acme-challenge.${CP_INSTANCE_ID}-my.apps TXT record set under the TP_CLUSTER_DOMAIN dns zone with the value mentioned in the output of above command.
After the record set is created, press Enter to complete the command.

```bash
oc create secret tls custom-my-tls \
  -n ${CP_INSTANCE_ID}-ns \
  --cert=$SCRATCH_DIR/config/live/${CP_MY_DNS_DOMAIN}/fullchain.pem \
  --key=$SCRATCH_DIR/config/live/${CP_MY_DNS_DOMAIN}/privkey.pem
```

### Certificate and Secret for TUNNEL Domain

```bash
export SCRATCH_DIR="/tmp/${CP_INSTANCE_ID}-tunnel"

certbot certonly --manual \
  --preferred-challenges=dns \
  --email ${EMAIL} \
  --server https://acme-v02.api.letsencrypt.org/directory \
  --agree-tos \
  -d "*.${CP_TUNNEL_DNS_DOMAIN}" \
  --config-dir "${SCRATCH_DIR}/config" \
  --work-dir "${SCRATCH_DIR}/work" \
  --logs-dir "${SCRATCH_DIR}/logs"
```

Do not interrupt the command.
Create the _acme-challenge.${CP_INSTANCE_ID}-tunnel.apps TXT record set under the TP_CLUSTER_DOMAIN dns zone with the value mentioned in the output of above command.
After the record set is created, press Enter to complete the command.

```bash
oc create secret tls custom-tunnel-tls \
  -n ${CP_INSTANCE_ID}-ns \
  --cert=$SCRATCH_DIR/config/live/${CP_TUNNEL_DNS_DOMAIN}/fullchain.pem \
  --key=$SCRATCH_DIR/config/live/${CP_TUNNEL_DNS_DOMAIN}/privkey.pem
```

### Create Record Sets for MY and TUNNEL Domains

Since we are using the Azure DNS Zones, we will need to add the new record sets under the DNS Zones so that `my` and `tunnel` domains are accessible.

Run the following commands to add the record sets

```bash
INGRESS_IP="$(az aro show -n ${TP_CLUSTER_NAME} -g ${TP_RESOURCE_GROUP} --query 'ingressProfiles[0].ip' -o tsv)"

## add record set for MY Domain
​​az network dns record-set a add-record \
 -g ${TP_DNS_RESOURCE_GROUP} \
 -z ${TP_CLUSTER_DOMAIN} \
 -n "*.${CP_INSTANCE_ID}-my.apps" \
 -a ${INGRESS_IP}

## add record set for TUNNEL Domain
​​az network dns record-set a add-record \
 -g ${TP_DNS_RESOURCE_GROUP} \
 -z ${TP_CLUSTER_DOMAIN} \
 -n "*.${CP_INSTANCE_ID}-tunnel.apps" \
 -a ${INGRESS_IP}

## Verify record sets
dig +short test.${CP_INSTANCE_ID}-my.${TP_DOMAIN}
dig +short test.${CP_INSTANCE_ID}-tunnel.${TP_DOMAIN}
```

## Information needed to be set on TIBCO® Control Plane

| Name                 | Sample value                                                                     | Notes                                                                     |
|:---------------------|:---------------------------------------------------------------------------------|:--------------------------------------------------------------------------|
| Node CIDR             | 10.0.2.0/23                                                                    | from Worker Node subnet Check [TP_WORKER_SUBNET_CIDR in cluster-setup](../cluster-setup/README.md#export-required-variables)                                      |
| Service CIDR             | 172.30.0.0/16                                                                    | Run the command az aro show -g ${TP_RESOURCE_GROUP} -n ${TP_CLUSTER_NAME} --query networkProfile.serviceCidr -o tsv                                        |
| Pod CIDR             | 10.128.0.0/14                                                                    |  Run the command az aro show -g ${TP_RESOURCE_GROUP} -n ${TP_CLUSTER_NAME} --query networkProfile.podCidr -o tsv                                        |
| Ingress class name   | openshift-default                                                                            | used for TIBCO Control Plane `my` and `tunnel` ingresses                                               |
| File storage class    |   azure-files-sc                                                                    | used for TIBCO Control Plane                                                                   |
| Disk storage class    |   azure-disk-sc                                                                    | used for Postgres                                                                   |
| Postgres |  postgresql.tibco-ext.svc.cluster.local:5432   | used for TIBCO Control Plane |
| Postgres database@username:password |  postgres@postgres:postgres   | used for TIBCO Control Plane |
| Network Policies Details for Control Plane Namespace | [Control Plane Network Policies Document](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#Installation/control-plane-network-policies.htm) |

## Export additional variables required for chart values
```bash
## Bootstrap and Configuration charts specific details
export TP_CONTAINER_REGISTRY_URL="csgprduswrepoedge.jfrog.io" # jfrog edge node url us-west-2 region, replace with container registry url as per your deployment region
export TP_CONTAINER_REGISTRY_USER="" # replace with your container registry username
export TP_CONTAINER_REGISTRY_PASSWORD="" # replace with your container registry password
export TP_CONTAINER_REGISTRY_REPOSITORY="tibco-platform-docker-prod" # replace with your container registry repository
```

## Generate and Create session-keys Secret (Required for Router Pods)
This secret is a required prerequisite for the platform-bootstrap chart. If this secret is not present in the Control Plane namespace, the router pods will fail to start correctly.
```bash
# Generate session keys and export as environment variables
export TSC_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)
export DOMAIN_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)

# Create the Kubernetes secret required by router pods, default secret name is session-keys
kubectl create secret generic session-keys -n ${CP_INSTANCE_ID}-ns \
  --from-literal=TSC_SESSION_KEY=${TSC_SESSION_KEY} \
  --from-literal=DOMAIN_SESSION_KEY=${DOMAIN_SESSION_KEY}
```

## Bootstrap Chart values

The following values can be stored in a file and passed to the platform-boostrap chart while deploying this chart.

> [!IMPORTANT]
> These values are for example only.

```bash
cat > aro-bootstrap-values.yaml <(envsubst '${TP_INGRESS_CLASS}, ${CP_TUNNEL_DNS_DOMAIN}, ${CP_MY_DNS_DOMAIN}, ${TP_ENABLE_NETWORK_POLICY}, ${TP_CONTAINER_REGISTRY_URL}, ${TP_CONTAINER_REGISTRY_USER}, ${TP_CONTAINER_REGISTRY_PASSWORD}, ${TP_CONTAINER_REGISTRY_REPOSITORY}, ${CP_INSTANCE_ID}, ${TP_NODE_CIDR}, ${TP_POD_CIDR}, ${TP_SERVICE_CIDR}, ${TP_FILE_STORAGE_CLASS}, ${TP_LOGSERVER_ENDPOINT}, ${TP_LOGSERVER_INDEX}, ${TP_LOGSERVER_USERNAME}, ${TP_LOGSERVER_PASSWORD}'  << 'EOF'
hybrid-proxy:
  enabled: true
  ingress:
    enabled: true
    ingressClassName: ${TP_INGRESS_CLASS}
    tls:
      - secretName: custom-tunnel-tls
        hosts:
          - '*.${CP_TUNNEL_DNS_DOMAIN}'
    hosts:
      - host: '*.${CP_TUNNEL_DNS_DOMAIN}'
        paths:
          - path: /
            pathType: Prefix
            port: 105
router-operator:
  enabled: true
  # SecretNames for environment variables TSC_SESSION_KEY and DOMAIN_SESSION_KEY.
  tscSessionKey:
    secretName: session-keys  # default secret name
    key: TSC_SESSION_KEY
  domainSessionKey:
    secretName: session-keys  # default secret name
    key: DOMAIN_SESSION_KEY
  ingress:
    enabled: true
    ingressClassName: "${TP_INGRESS_CLASS}"
    tls:
      - secretName: custom-my-tls
        hosts:
          - '*.${CP_MY_DNS_DOMAIN}'
    hosts:
      - host: '*.${CP_MY_DNS_DOMAIN}'
        paths:
          - path: /
            pathType: Prefix
            port: 100
# uncomment to enable logging
# otel-collector:
  # enabled: true
global:
  tibco:
    createNetworkPolicy: ${TP_ENABLE_NETWORK_POLICY}
    # uncomment and adjust the following section for network policy if you are enabling network policies
    # networkPolicy:
    #   # Create deprecated network policies
    #   createDeprecatedPolicies: false
    #   # Enable or disable the creation of cluster-wide network policies
    #   createClusterScopePolicies: true
    #   # Enable or disable the creation of internet-facing network policies
    #   createInternetScopePolicies: true
    #   kubeApiServer:
    #     CIDR: "10.0.0.0/24"
    #     port: 6443
    #   kubeDns:
    #     egress:
    #     - to:
    #       - namespaceSelector: {}
    #         podSelector:
    #           matchLabels:
    #             dns.operator.openshift.io/daemonset-dns: default
    #       ports:
    #       - protocol: UDP
    #         port: 5353
    #       - protocol: TCP
    #         port: 5353
    #   database:
    #     CIDR: "${TP_POD_CIDR}" # podCIDR
    #     port: 5432
    containerRegistry:
      url: "${TP_CONTAINER_REGISTRY_URL}"
      username: "${TP_CONTAINER_REGISTRY_USER}"
      password: "${TP_CONTAINER_REGISTRY_PASSWORD}"
      repository: "${TP_CONTAINER_REGISTRY_REPOSITORY}"
    controlPlaneInstanceId: "${CP_INSTANCE_ID}"
    serviceAccount: "${CP_INSTANCE_ID}-sa"
  external:
    clusterInfo:
      nodeCIDR: "${TP_NODE_CIDR}"
      podCIDR: "${TP_POD_CIDR}"
      serviceCIDR: "${TP_SERVICE_CIDR}"
    dnsTunnelDomain: "${CP_TUNNEL_DNS_DOMAIN}"
    dnsDomain: "${CP_MY_DNS_DOMAIN}"
    storage:
      resources:
        requests:
          storage: 10Gi
      storageClassName: "${TP_FILE_STORAGE_CLASS}"
    # uncomment following section if logging is enabled
    # logserver:
    #   endpoint: ${TP_LOGSERVER_ENDPOINT}
    #   index: ${TP_LOGSERVER_INDEX}
    #   username: ${TP_LOGSERVER_USERNAME}
    #   password: ${TP_LOGSERVER_PASSWORD}
EOF
)
```

## Next Steps

Please proceed with deployment of TIBCO Control Plane on your ARO cluster as per [the steps mentioned in the document](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#Installation/deploying-control-plane-in-kubernetes.htm)

# Clean-up

Refer to [the steps to delete TIBCO Control Plane](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#Installation/uninstalling-tibco-control-plane.htm).

Change the directory to [aro (Azure Red Hat OpenShift)/scripts/](../../aro%20(Azure%20Red%20Hat%20OpenShift)/scripts) to proceed with the next steps.
```bash
cd aro\ \(Azure\ Red\ Hat\ OpenShift\)/scripts
```

> [!IMPORTANT]
> If you have used a common cluster for both TIBCO Control Plane and Data Plane, please check the script and add modifications
> so that common resources are not deleted.

For the tools charts uninstallation, File storage mount and cluster deletion, we have provided a helper [clean-up](../scripts/clean-up.sh).

```bash
./clean-up.sh
```