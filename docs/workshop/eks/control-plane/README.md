Table of Contents
=================
<!-- TOC -->
* [Table of Contents](#table-of-contents)
* [TIBCO® Control Plane EKS Workshop](#tibco-control-plane-eks-workshop)
  * [Export required variables](#export-required-variables)
  * [Install External DNS](#install-external-dns)
  * [Create-Configure AWS Resources](#create-configure-aws-resources)
    * [Using AWS CLI](#using-aws-cli)
      * [Create Amazon EFS](#create-amazon-efs)
      * [Create Amazon RDS instance](#create-amazon-rds-instance)
    * [Using Crossplane claims](#using-crossplane-claims)
      * [Pre-requisites to create namespace and service account](#pre-requisites-to-create-namespace-and-service-account)
      * [Install Crossplane claims](#install-crossplane-claims)
    * [Verifying AWS Resources creation](#verifying-aws-resources-creation)
    * [Create Storage Class](#create-storage-class)
* [TIBCO® Control Plane Deployment](#tibco-control-plane-deployment)
  * [Configure Route53 records, Certificates](#configure-route53-records-certificates)
  * [Install Additional Ingress Controller [OPTIONAL]](#install-additional-ingress-controller-optional)
    * [Nginx Ingress Controller](#install-nginx-ingress-controller)
  * [Information needed to be set on TIBCO® Control Plane](#information-needed-to-be-set-on-tibco-control-plane)
  * [Export additional variables required for chart values](#export-additional-variables-required-for-chart-values)
  * [Generate and Create session-keys Secret (Required for Router Pods)](#generate-and-create-session-keys-secret-required-for-router-pods)
  * [Bootstrap Chart values](#bootstrap-chart-values)
  * [Next Steps](#Next-steps)
* [Clean-up](#clean-up)
<!-- TOC -->

# TIBCO® Control Plane EKS Workshop

The goal of this workshop is to provide hands-on experience to prepare Amazon EKS cluster to be used as a TIBCO® Control Plane. In order to deploy TIBCO Control Plane, you need to have a Kubernetes cluster with some necessary tools installed. This workshop will guide you to install the necessary tools.

> [!IMPORTANT]
> This workshop is NOT meant for production deployments.

To perform the steps mentioned in this workshop document, it is assumed you already have an Amazon EKS cluster created and can connect to it.

> [!Note]
> To create Amazon EKS cluster and connect to it using kubeconfig, please refer 
> [steps for EKS cluster creation](../cluster-setup/README.md#amazon-eks-cluster-creation)

## Export required variables

Following variables are required to be set to run the scripts and are referred throughout the document.
Please set/adjust the values of the variables as expected.

> [!NOTE]
> We have used the prefixes `TP_` and `CP_` for the required variables.
> These prefixes stand for "TIBCO PLATFORM" and "Control Plane" respectively.

```bash
## AWS specific values
export AWS_PAGER=""
export AWS_REGION="us-west-2" # aws region to be used for deployments
export TP_CLUSTER_REGION="${AWS_REGION}"
export TP_WAIT_FOR_RESOURCE_AVAILABLE="false"

## Cluster configuration specific variables
export TP_VPC_CIDR="10.180.0.0/16" # vpc cidr for the cluster
export TP_SERVICE_CIDR="172.20.0.0/16" # service IPv4 cidr for the cluster
export TP_CLUSTER_NAME="eks-cluster-${CLUSTER_REGION}" # name of the EKS cluster prvisioned, used for chart deployment
export KUBECONFIG=`pwd`/${TP_CLUSTER_NAME}.yaml # kubeconfig saved as cluster name yaml

## Helm repo specific details
export TP_TIBCO_HELM_CHART_REPO="https://tibcosoftware.github.io/tp-helm-charts" # location of charts repo url

## Domain, Storage related values and Network policy flag
export TP_HOSTED_ZONE_DOMAIN="aws.example.com" # replace with the Top Level Domain (TLD) to be used
export TP_STORAGE_CLASS_EFS=efs-sc # name of efs storge class
export TP_ENABLE_NETWORK_POLICY="true" # set to true to enable network policies

## TIBCO Control Plane RDS specific details
export TP_RDS_AVAILABILITY="public" # public or private
export TP_RDS_USERNAME="TP_rdsadmin" # replace with desired master username
export TP_RDS_MASTER_PASSWORD="TP_DBAdminPassword" # replace with desired master user password
export TP_RDS_INSTANCE_CLASS="db.t3.medium" # replace with desired db instance class
export TP_RDS_PORT="5432" # replace with desired db port

## Required by external-dns chart
export TP_MAIN_INGRESS_CONTROLLER=alb
export TP_INGRESS_CONTROLLER=nginx # This value can be same as TP_MAIN_INGRESS_CONTROLLER or nginx if you're using nginx

## Required for configuring Logserver for TIBCO Control Plane services
export TP_LOGSERVER_ENDPOINT="" # logserver endpoint
export TP_LOGSERVER_INDEX="" # logserver index to push the logs to
export TP_LOGSERVER_USERNAME="" # logserver username
export TP_LOGSERVER_PASSWORD="" # logserver password
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
  - "--ingress-class=${TP_MAIN_INGRESS_CONTROLLER}"
sources:
  - ingress
  - service
domainFilters:
  - ${TP_HOSTED_ZONE_DOMAIN}
EOF
```

## Create-Configure AWS Resources

### Using AWS CLI

Change the directory to [../scripts/](../scripts/) to proceed with the next steps.
```bash
cd ../scripts/
```

#### Create Amazon EFS
Before deploying `storage class`; we need to set up AWS EFS. For more information about EFS, please refer:
* workshop to create EFS: [link](https://archive.eksworkshop.com/beginner/190_efs/launching-efs/)
* create EFS in AWS console: [link](https://docs.aws.amazon.com/efs/latest/ug/gs-step-two-create-efs-resources.html)
* create EFS with scripts: [link](https://github.com/kubernetes-sigs/aws-efs-csi-driver/blob/master/docs/efs-create-filesystem.md)

We have provided an [EFS creation script](../scripts/create-efs-control-plane.sh) to create EFS.
```bash
./create-efs-control-plane.sh
```
#### Create Amazon RDS instance

We have provided a [RDS creation script](../scripts/create-rds.sh) to create RDS instance.
```bash
export ${TP_WAIT_FOR_RESOURCE_AVAILABLE}="false" # set to true to wait for resources to be available, before proceeding
./create-rds.sh
```

> [!IMPORTANT]
> Please note that the RDS db instance created above does not enforce SSL, by default. It has to be manually configured.
> To enforce SSL while to connecting to the instance, please follow the steps mentioned under [Requiring an SSL connection to a PostgreSQL DB instance](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/PostgreSQL.Concepts.General.SSL.html#PostgreSQL.Concepts.General.SSL.Requiring)

### Using Crossplane claims

To use crossplane to create AWS resources, please make sure you have installed crossplane following [the steps under Install Crossplane in cluster-setup document](../cluster-setup/README.md#install-crossplane-optional)

We will be creating [crossplane claims](https://docs.crossplane.io/latest/concepts/claims/) to create AWS resources.

#### Pre-requisites to create namespace and service account

We will be creating a namespace where the crossplane claims are to be installed.
This is the same namespace where the TIBCO Control Plane charts are to be deployed, too.

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

> [!NOTE]
> If you have are going to use crossplane to create service account, please skip running below `kubectl` command to create service account and skip to [Install crossplane claims](#install-crossplane-claims) section.

Create a service account in the namespace. This service account is used for TIBCO Control Plane deployment.

```bash
kubectl create serviceaccount ${CP_INSTANCE_ID}-sa -n ${CP_INSTANCE_ID}-ns
```

If you are going to use Amazon Simple Email Service (SES) as an email server for TIBCO Control Plane, you need to make
sure that the service account, you created, can assume an AWS Identity and Access Management (IAM) role with necessary actions to send emails. This is managed by [IAM roles for service accounts (IRSA)](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

To use this feature, you need to annotate the service account with the Amazon Resource Name (ARN) of the IAM role that you want the service account to assume.

Following is sample command:

```bash
kubectl annotate serviceaccount ${CP_INSTANCE_ID}-sa -n ${CP_INSTANCE_ID}-ns eks.amazonaws.com/role-arn=<IAM_ROLE_ARN>
```
Replace the <IAM_ROLE_ARN> with the ARN of the IAM Role.

#### Install Crossplane claims

As part of claims, we will create following resources:
  1. Amazon Elastic File System (EFS)
  2. Kubernete storage class using EFS ID created in (1)
  3. Amazon Relational Database Service (RDS) DB cluster of Aurora Postgres
  4. IAM Role and Policy Attachment
  5. Kubernetes service account and annotate it with IAM Role ARN from (4) to enable sending emails (using pre-existing identity)

> [!NOTE]
> This also creates the secrets in the namespace where the chart will be deployed.
> TIBCO Control Plane services can access these resources using the secrets.

> [!IMPORTANT]
> Please note that the RDS DB cluster of Aurora Postgres created using below crossplane claims enforces SSL.


```bash
export CP_RESOURCE_PREFIX="platform" # unique id to add to AWS resources as prefix (alphanumeric string of max 10 chars)

helm upgrade --install --wait --timeout 1h \
  -n ${CP_INSTANCE_ID}-ns crossplane-claims-aws dp-config-aws \
  --render-subchart-notes \
  --labels layer=4 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" \
  -f <(envsubst '${CP_INSTANCE_ID}, ${CP_RESOURCE_PREFIX}, ${TP_CLUSTER_NAME}, ${TP_STORAGE_CLASS_EFS}' <<'EOF'
crossplane-components:
  enabled: true
  claims:
    enabled: true
    commonResourcePrefix: "${CP_RESOURCE_PREFIX}"
    commonTags:
      cluster-name: ${TP_CLUSTER_NAME}
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
        name: "${TP_STORAGE_CLASS_EFS}"
      resourceTags:
        resource-name: efs
        cost-center: shared
    auroraCluster:
      create: true
      connectionDetailsSecret: "${CP_INSTANCE_ID}-aurora-details"
      numberOfInstances: 1
      globalDatabase:
        primaryCluster:
          create: false
        secondaryCluster:
          create: false
      mandatoryConfigurationParameters:
        autoMinorVersionUpgrade: false
        databaseName: "postgres"
        dbInstanceClass: "db.t3.medium"
        dbParameterGroupFamily: "aurora-postgresql16"
        engine: "aurora-postgresql"
        engineVersion: "16.8"
        engineMode: "provisioned"
        masterUsername: "useradmin"
        port: 5432
        publiclyAccessible: false
      additionalConfigurationParameters:
        applyImmediately: "true"
        groupFamilyParameters:
          - parameterName: rds.force_ssl
            parameterValue: '1'
            applyMethod: immediate
        storageEncrypted: "true"
        storageType: aurora
      resourceTags:
        resource-name: aurora-cluster
        cost-center: shared
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

### Verifying AWS Resources creation
After following the steps to create the AWS resources above, you should see the EFS, IAM Role and RDS DB cluster/instance of Aurora Postgres/PostgreSQL in the AWS console.

If you have used crossplane, you can additionally verify the claims and status with below `kubectl` commands
```bash
kubectl get -n ${CP_INSTANCE_ID}-ns TibcoEFSSC 
kubectl get -n ${CP_INSTANCE_ID}-ns TibcoRoleSA
kubectl get -n ${CP_INSTANCE_ID}-ns TibcoAuroraCluster

# If storage class and service account are created using crossplane
kubectl get storageclass
kubectl get serviceaccount -n ${CP_INSTANCE_ID}-ns

# Details for postgreSQL instance connection
kubectl get secret -n ${CP_INSTANCE_ID}-ns ${CP_INSTANCE_ID}-aurora-details -o yaml
```

### Create Storage Class
> [!IMPORTANT]
> If you have used crossplane to create storage class, please skip to the section [Install Additional Ingress Controller [OPTIONAL]](#install-additional-ingress-controller-optional).

After running [Create EFS script](#create-efs), you will get an EFS ID output like `fs-052ba079dbc2bffb4`.

```bash
## following variable is required to create the storage class
export TP_EFS_ID="fs-052ba079dbc2bffb4" # replace with the EFS ID created in your installation

kubectl apply -f <(envsubst '${TP_STORAGE_CLASS_EFS}, ${TP_EFS_ID}' <<'EOF'
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: "${TP_STORAGE_CLASS_EFS}"
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: efs.csi.aws.com
mountOptions:
  - soft
  - timeo=300
  - actimeo=1
parameters:
  provisioningMode: "efs-ap"
  fileSystemId: "${TP_EFS_ID}"
  directoryPerms: "700"
EOF
)
```

# TIBCO® Control Plane Deployment

## Configure Route53 records, Certificates
We recommend that you use different Route53 records and certificates for `my` (control plane application) and `tunnel` (hybrid connectivity) domains. You can use wildcard domain names for these control plane application and hybrid connecivity domains.

We recommend that you use different `CP_INSTANCE_ID` to distinguish multiple control plane installations within a cluster.

Please export below variables and values related to domains:
```bash
## Domains
export CP_INSTANCE_ID="cp1" # unique id to identify multiple cp installation in same cluster (alphanumeric string of max 5 chars)
export TP_MY_DOMAIN=${CP_INSTANCE_ID}-my.${TP_HOSTED_ZONE_DOMAIN} # domain to be used
export TP_TUNNEL_DOMAIN=${CP_INSTANCE_ID}-tunnel.${TP_HOSTED_ZONE_DOMAIN} # domain to be used
```
`TP_HOSTED_ZONE_DOMAIN` is exported as part of [Export required variables](#export-required-variables)

You can use the following services to register domain and manage certificates.
* [Amazon Route 53](https://aws.amazon.com/route53/): to manage DNS. You can register your Control Plane domain in Route 53. And, give permission to external-dns to add new record.
* [AWS Certificate Manager (ACM)](https://docs.aws.amazon.com/acm/latest/userguide/acm-overview.html): to manage SSL certificate. You can create wildcard certificates for `*.<TP_MY_DOMAIN>` and `*.<TP_TUNNEL_DOMAIN>` in ACM.
* aws-load-balancer-controller: to create AWS ALB. It will automatically create AWS ALB and add SSL certificate to ALB.
* network-load-balancer service: to create AWS NLB. It will automatically create AWS NLB and add the SSL certificate provided in values.
* external-dns: to create DNS record in Route 53. It will automatically create DNS record for ingress objects and load balancer service..

For this workshop, you will need to
* register a domain name in Route 53. You can follow this [link](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/domain-register.html) to register a domain name in Route 53.
* create a wildcard certificate in ACM. You can follow this [link](https://docs.aws.amazon.com/acm/latest/userguide/gs-acm-request-public.html) to create a wildcard certificate in ACM.

## Install Additional Ingress Controller [OPTIONAL]

You can additionally install another ingress controller. We have provided the helm chart called `dp-config-aws` that encapsulates the installation of ingress controller. 

It will create the following resources:
* a main ingress object which will be able to create AWS Application Load Balancer (ALB) and act as an ingress controller for TIBCO Control Plane cluster
* annotation for external-dns to create DNS record for the main ingress [external-dns chart is already deployed while installing [Install External DNS](#install-external-dns)]

### Install Nginx Ingress Controller
```bash
helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ingress-system dp-config-aws-nginx dp-config-aws \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" \
  --labels layer=1 \
  --version "^1.0.0" -f - <<EOF
dns:
  domain: "${TP_MY_DOMAIN}"
httpIngress:
  enabled: true
  name: nginx
  backend:
    serviceName: dp-config-aws-nginx-ingress-nginx-controller
  annotations:
    alb.ingress.kubernetes.io/group.name: "${TP_MY_DOMAIN}"
    # this is to support 1.3 TLS for ALB, Please refer AWS doc: https://aws.amazon.com/about-aws/whats-new/2023/03/application-load-balancer-tls-1-3/
    alb.ingress.kubernetes.io/ssl-policy: "ELBSecurityPolicy-TLS13-1-2-2021-06"
    external-dns.alpha.kubernetes.io/hostname: "*.${TP_MY_DOMAIN}"
    # this will be used for external-dns annotation filter
    kubernetes.io/ingress.class: alb
ingress-nginx:
  enabled: true
  controller:
    config:
      # refer: https://github.com/kubernetes/ingress-nginx/blob/main/docs/user-guide/nginx-configuration/configmap.md to know more about the following configuration options
      # to support passing the incoming X-Forwarded-* headers to upstreams
      use-forwarded-headers: "true"
      # to support large file upload from Control Plane
      proxy-body-size: "150m"
      # to set the size of the buffer used for reading the first part of the response received
      proxy-buffer-size: 16k
EOF
```

You can optionally use the same ingress controller for tunnel traffic, as well. To do so, you will need to create another ingress object which sends the traffic to nginx service. This means, the helm chart `dp-config-aws` needs to be re-deployed with different release-name. This is to ensure that the ingress for tunnel domain is created. (The alternative to this is using a load balancer service)

```bash
helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ingress-system dp-config-aws-tunnel dp-config-aws \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" \
  --labels layer=1 \
  --version "^1.0.0" -f - <<EOF
dns:
  domain: "${TP_TUNNEL_DOMAIN}"
httpIngress:
  enabled: true
  name: nginx-tun
  backend:
    serviceName: dp-config-aws-tunnel-ingress-nginx-controller
  annotations:
    # keeping the same group.name ensures only one ALB is created
    alb.ingress.kubernetes.io/group.name: "${TP_MY_DOMAIN}"
    # this is to support 1.3 TLS for ALB, Please refer AWS doc: https://aws.amazon.com/about-aws/whats-new/2023/03/application-load-balancer-tls-1-3/
    alb.ingress.kubernetes.io/ssl-policy: "ELBSecurityPolicy-TLS13-1-2-2021-06"
    external-dns.alpha.kubernetes.io/hostname: "*.${TP_TUNNEL_DOMAIN}"
    # this will be used for external-dns annotation filter
    kubernetes.io/ingress.class: alb
# you don't need to deploy the ingress controller again
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

> [!IMPORTANT]
> You will need to provide this ingress class name i.e. nginx to TIBCO Control Plane.

## Information needed to be set on TIBCO® Control Plane

| Name                 | Sample value                                                                     | Notes                                                                     |
|:---------------------|:---------------------------------------------------------------------------------|:--------------------------------------------------------------------------|
| VPC_CIDR             | 10.180.0.0/16                                                                    | from EKS recipe                                                                                 |
| Ingress class name   | alb / nginx                                                                           | used for TIBCO Control Plane                                                 |
| EFS storage class    | efs-sc                                                                           | used for TIBCO Control Plane                                                                   |
| EKS Default storage class    | gp2                                                                           | Not recommended for TIBCO Control Plane                                                                |
| RDS DB instance resource arn (if created using script) | arn:aws:rds:\<TP_CLUSTER_REGION\>:\<AWS_ACCOUNT_ID\>:db:${TP_CLUSTER_NAME}-db   | used for TIBCO Control Plane |
| RDS DB details (if created using crossplane) | Secret `${CP_INSTANCE_ID}-rds-details` in `${CP_INSTANCE_ID}-ns` namespace Refer [Install claims](#install-claims) section  | used for TIBCO Control Plane |
| Network Policies Details for Control Plane Namespace | [Control Plane Network Policies Document](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#Installation/control-plane-network-policies.htm) |

## Export additional variables required for chart values
```bash
## Bootstrap and Configuration charts specific details
export TP_MAIN_INGRESS_CONTROLLER=alb
export TP_CONTAINER_REGISTRY_URL="csgprduswrepoedge.jfrog.io" # jfrog edge node url us-west-2 region, replace with container registry url as per your deployment region
export TP_CONTAINER_REGISTRY_USER="" # replace with your container registry username
export TP_CONTAINER_REGISTRY_PASSWORD="" # replace with your container registry password
export TP_MY_DOMAIN_CERT_ARN="" # replace with your TP_MY_DOMAIN certificate arn
export TP_TUNNEL_DOMAIN_CERT_ARN="" # replace with your TP_TUNNEL DOMAIN certificate arn
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

Following values can be stored in a file and passed to the platform-boostrap chart while deploying this chart.

> [!IMPORTANT]
> These values are for example only.

```bash
cat > aws-bootstrap-values.yaml <(envsubst '${TP_ENABLE_NETWORK_POLICY}, ${TP_CONTAINER_REGISTRY_URL}, ${TP_CONTAINER_REGISTRY_USER}, ${TP_CONTAINER_REGISTRY_PASSWORD}, ${CP_INSTANCE_ID}, ${TP_TUNNEL_DOMAIN}, ${TP_MY_DOMAIN}, ${TP_VPC_CIDR}, ${TP_SERVICE_CIDR}, ${TP_STORAGE_CLASS_EFS}, ${TP_INGRESS_CONTROLLER}, ${TP_MY_DOMAIN_CERT_ARN}, ${TP_TUNNEL_DOMAIN_CERT_ARN}, ${TP_LOGSERVER_ENDPOINT}, ${TP_LOGSERVER_INDEX}, ${TP_LOGSERVER_USERNAME}, ${TP_LOGSERVER_PASSWORD}'  << 'EOF'
hybrid-proxy:
  # uncomment the following section (ports and service values), if you want to use a load balancer service for hybrid-proxy
  # ports:
  #   api:
  #     enabled: true
  #     serviceEnabled: false
  #     containerPort: 88
  #     servicePort: 88
  #     protocol: TCP
  #     targetPort: api
  #   tunnel:
  #     enabled: true
  #     serviceEnabled: true
  #     containerPort: 443
  #     servicePort: 443
  #     protocol: TCP
  #     targetPort: tunnel
  # service:
  #   type: LoadBalancer
  #   loadBalancerClass: "service.k8s.aws/nlb"
  #   allocateLoadBalancerNodePorts: false
  #   # annotation for load balancer service
  #   annotations:
  #     external-dns.alpha.kubernetes.io/hostname: "*.${TP_TUNNEL_DOMAIN}"
  #     service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "${TP_TUNNEL_DOMAIN_CERT_ARN}"
  #     service.beta.kubernetes.io/aws-load-balancer-attributes: load_balancing.cross_zone.enabled=false
  #     service.beta.kubernetes.io/aws-load-balancer-target-group-attributes: preserve_client_ip.enabled=true
  #     service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
  #     service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
  #     service.beta.kubernetes.io/aws-load-balancer-type: external
  #     service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
  #     # optional policy to use TLS 1.3, for `nlb`
  #     service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy: "ELBSecurityPolicy-TLS13-1-2-2021-06"
  # alternatively, uncomment the following section, if you have deployed additional ingress controller (e.g. nginx) and want to use ingress for hybrid-proxy
  # ingress:
  #   enabled: true
  #   ingressClassName: "${TP_INGRESS_CONTROLLER}"
  #   # uncomment annotations from following section, as per your requirements
  #   annotations:
  #   # annotations for `nginx` ingress class
  #   # refer: https://github.com/kubernetes/ingress-nginx/blob/main/docs/user-guide/nginx-configuration/annotations.md to know more about the following annotation
  #   # uncomment the following annotations, if not set globally using controller.config
  #     nginx.ingress.kubernetes.io/proxy-buffer-size: 16k
  #     nginx.ingress.kubernetes.io/proxy-body-size: "150m"
  #   # uncomment following tls section to secure your ingress resource
  #   tls:
  #     - hosts:
  #         - '*.${TP_TUNNEL_DOMAIN}'
  #      # create a secret containing a TLS private key and certificate, and replace the value for secretName below
  #      secretName: hybrid-proxy-tls
  #   hosts:
  #     - host: '*.${TP_TUNNEL_DOMAIN}'
  #       paths:
  #         - path: /
  #           pathType: Prefix
  #           port: 105
router-operator:
  ingress:
    enabled: true
  # SecretNames for environment variables TSC_SESSION_KEY and DOMAIN_SESSION_KEY.
  tscSessionKey:
    secretName: session-keys  # default secret name
    key: TSC_SESSION_KEY
  domainSessionKey:
    secretName: session-keys  # default secret name
    key: DOMAIN_SESSION_KEY
    ingressClassName: "${TP_INGRESS_CONTROLLER}"
    #   # uncomment annotations from following section, as per your requirements
    #   annotations:
    #   # annotations for `nginx` ingress class
    #   # refer: https://github.com/kubernetes/ingress-nginx/blob/main/docs/user-guide/nginx-configuration/annotations.md to know more about the following annotation
    #    # uncomment the following annotations, if not set globally using controller.config
    #    nginx.ingress.kubernetes.io/proxy-buffer-size: 16k
    #    nginx.ingress.kubernetes.io/proxy-body-size: "150m"
    #   # annotation for `alb` ingress class
    #   external-dns.alpha.kubernetes.io/hostname: "*.${TP_MY_DOMAIN}"
    #   alb.ingress.kubernetes.io/group.name: "${TP_MY_DOMAIN}"
    #   alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS": 443}]'
    #   alb.ingress.kubernetes.io/backend-protocol: HTTP
    #   alb.ingress.kubernetes.io/scheme: internet-facing
    #   alb.ingress.kubernetes.io/success-codes: 200-399
    #   alb.ingress.kubernetes.io/target-type: ip
    #   alb.ingress.kubernetes.io/healthcheck-port: '88'
    #   alb.ingress.kubernetes.io/healthcheck-path: "/health"
    #   alb.ingress.kubernetes.io/certificate-arn: "${TP_MY_DOMAIN_CERT_ARN}"
    #   # optional policy to use TLS 1.3, for `alb` ingress class
    #   alb.ingress.kubernetes.io/ssl-policy: "ELBSecurityPolicy-TLS13-1-2-2021-06"
    hosts:
    #   # uncomment following tls section to secure your ingress resource
    #   tls:
    #     - hosts:
    #         - '*.${TP_MY_DOMAIN}'
    #      # create a secret containing a TLS private key and certificate, and replace the value for secretName below
    #      secretName: router-tls
      - host: '*.${TP_MY_DOMAIN}'
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
    containerRegistry:
      url: "${TP_CONTAINER_REGISTRY_URL}"
      username: "${TP_CONTAINER_REGISTRY_USER}"
      password: "${TP_CONTAINER_REGISTRY_PASSWORD}"
      repository: "tibco-platform-docker-prod"
    controlPlaneInstanceId: "${CP_INSTANCE_ID}"
    serviceAccount: "${CP_INSTANCE_ID}-sa"
    # uncomment to enable logging
    # logging:
    #   fluentbit:
    #     enabled: true
  external:
    clusterInfo:
      nodeCIDR: "${TP_VPC_CIDR}"
      podCIDR: "${TP_VPC_CIDR}"
      serviceCIDR: "${TP_SERVICE_CIDR}"
    dnsTunnelDomain: "${TP_TUNNEL_DOMAIN}"
    dnsDomain: "${TP_MY_DOMAIN}"
    storage:
      storageClassName: "${TP_STORAGE_CLASS_EFS}"
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

Please proceed with deployment of TIBCO Control Plane on your EKS cluster as per [the steps mentioned in the document](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#Installation/deploying-control-plane-in-kubernetes.htm)

# Clean-up

Refer to [the steps to delete TIBCO Control Plane](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#Installation/uninstalling-tibco-control-plane.htm).

Change the directory to [../scripts/](../scripts/) to proceed with the next steps.
```bash
cd ../scripts/
```

Set the following variable with value false, if you want to keep the cluster and delete only the helm charts and AWS resources
```bash
export TP_DELETE_CLUSTER=false # default value is "true"
export CP_RESOURCE_PREFIX=platform # required, if you are using crossplane to create AWS resources
```

> [!IMPORTANT]
> If you have used a common cluster for both TIBCO Control Plane and Data Plane, please check the script and add modifications
> so that common resources are not deleted. (e.g. storage class, EFS, EKS Cluster, crossplane role, etc.)

For the tools charts uninstallation, EFS mount and security groups deletion and cluster deletion, we have provided a helper [clean-up](../scripts/clean-up-control-plane.sh).

> [!IMPORTANT]
> Please make sure the resources to be deleted are in started/scaled-up state (e.g. RDS DB cluster/instance, EKS cluster nodegroups)

```bash
./clean-up-control-plane.sh
```