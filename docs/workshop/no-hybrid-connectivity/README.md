Table of Contents
=================
<!-- TOC -->
* [Table of Contents](#table-of-contents)
* [Data Plane Deployment Without Hybrid Connectivity](#data-plane-deployment-without-hybrid-connectivity)
  * [Overview](#overview)
  * [Prerequisites](#prerequisites)
  * [Common Prerequisites](#common-prerequisites)
  * [Deployment Methods](#deployment-methods)
    * [Deploy with Network Load Balancer (NLB)](#deploy-with-network-load-balancer-nlb)
    * [Deploy with Application Load Balancer (ALB)](#deploy-with-application-load-balancer-alb)
    * [Control Tower Data Plane Deployment](#control-tower-data-plane-deployment)
<!-- TOC -->

# Data Plane Deployment Without Hybrid Connectivity 

## Overview

This guide covers ways of deploying Data Plane without hybrid connectivity. 

> [!NOTE]
> **This documentation covers AWS EKS  Data Plane deployment (using NLB or ALB) and Control Tower Data Plane deployment on MicroK8s (single-cluster Kubernetes on bare metal).** For other cloud providers, please follow the respective steps from the workshop documentation and make vendor-specific changes for ingress and load balancer resources accordingly.

## Prerequisites

Before starting this workshop, ensure you have:

- **Kubernetes Cluster**: Amazon EKS cluster created and accessible
  - Refer to [EKS cluster creation steps](../eks/cluster-setup/README.md#amazon-eks-cluster-creation)
- **Helm**: Version 3.18 or above
- **AWS Load Balancer Controller**: Installed and configured
- **External DNS**: Configured (optional, for automatic DNS registration)
- **Domain Name**: Registered domain for Data Plane services
- **SSL Certificate**: Wildcard certificate (recommended to use AWS ACM)

## Common Prerequisites

Follow the main Data Plane documentation for these common setup steps:

1. **[Export Required Variables](../eks/data-plane/README.md#export-required-variables)**
   - Set AWS region, cluster name, VPC CIDR, etc.
   - Set domain and ingress controller preferences

2. **[Install External DNS](../eks/data-plane/README.md#install-external-dns)**
   - Required for automatic DNS record creation

3. **[Setup DNS](../eks/data-plane/README.md#setup-dns)**
   - Register domain in Route 53
   - Create wildcard SSL certificate in ACM

4. **[Create Amazon EFS](../eks/data-plane/README.md#create-amazon-efs)**
   - Use the provided script or create manually

5. **[Create Storage Class](../eks/data-plane/README.md#create-storage-class)**
   - Deploy dp-config-aws for EBS and EFS storage classes

> [!TIP]
> Complete all the above prerequisites from the main Data Plane documentation before proceeding with deployment. Observability tools (Elastic Stack and Prometheus) should be installed as per the [main Data Plane documentation](../eks/data-plane/README.md#install-observability-tools).

## Deployment Methods

Data Plane deployment with no hybrid connectivity can be exposed via **NLB** and **ALB** (also supported for Control Tower Data Plane deployment). Choose one of the following options based on your infrastructure and requirements:

- **NLB**: Network Load Balancer (AWS) - Layer 4 load balancing, high performance, simpler configuration
- **ALB**: Application Load Balancer (AWS) - Layer 7 load balancing, advanced routing capabilities, integrated with Kubernetes Ingress
- **Control Tower Data Plane**: K8s cluster (MicroK8s) on bare metal VM

During Data Plane registration in TIBCO® Control Plane, you will receive a helm install command for `dp-configure-namespace` chart. You need to **configure it based on your chosen deployment method**.

#### Deploy with Network Load Balancer (NLB)

When using Data Plane deployment with NLB, you need to append additional parameters to the `dp-configure-namespace` chart installation command. This will create an NLB as a Kubernetes LoadBalancer service to expose the Data Plane.

**Follow these steps:**

**Step 1: Add NLB Parameters**

Add these parameters to the helm install command of `dp-configure-namespace` chart provided by TIBCO® Control Plane:

```bash
# Set the ACM Certificate ARN for SSL/TLS
export ACM_CERTIFICATE_ARN="arn:aws:acm:us-west-2:123456789012:certificate/12345678-1234-1234-1234-123456789012"

# 2. Run the Helm Upgrade / Install
# Note: Below is just a sample command. Please replace the values with your actual values.
# For adding additional annotations, please refer https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/guide/service/annotations/
helm upgrade --install haproxy-ingress haproxytech/kubernetes-ingress \
  --create-namespace --namespace haproxy-controller \
  --set haproxy.controller.service.type=LoadBalancer \
  --set haproxy.controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="external" \
  --set haproxy.controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-nlb-target-type"="ip" \
  --set haproxy.controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"="internet-facing" \
  --set haproxy.controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-cross-zone-load-balancing-enabled"="true" \
  --set haproxy.controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-ssl-cert"="${ACM_CERTIFICATE_ARN}" \
  --set haproxy.controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-ssl-ports"="443"
```

**What these parameters do:**
- `service.type=LoadBalancer` - Creates an NLB instead of ClusterIP
- `aws-load-balancer-type=external` - Uses AWS Load Balancer Controller
- `nlb-target-type=ip` - Routes traffic to pod IPs directly
- `scheme=internet-facing` - Makes NLB publicly accessible
- `cross-zone-load-balancing-enabled=true` - Enables high availability across AZs
- `aws-load-balancer-ssl-cert` - Attaches ACM certificate for SSL/TLS termination

**Step 2: Verify NLB Deployment**

After deploying with these parameters, verify the NLB creation and domain resolution:

```bash
# Set your namespace
export DP_NAMESPACE="haproxy" # or your actual Data Plane namespace

# 1. Check the LoadBalancer service
kubectl get svc -n ${DP_NAMESPACE}

# 2. Get NLB endpoint
export DP_NLB_ENDPOINT=$(kubectl get svc -n ${DP_NAMESPACE} -l app.kubernetes.io/name=haproxy -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
echo "NLB Endpoint: ${DP_NLB_ENDPOINT}"

# 3. Verify DNS resolution
nslookup ${TP_DOMAIN}

# 4. Test connectivity
curl -k https://${TP_DOMAIN}

# 5. Get NLB IP addresses
nslookup ${DP_NLB_ENDPOINT}
```

> [!IMPORTANT]
> **Verification checklist:**
> - LoadBalancer service is created successfully
> - EXTERNAL-IP/hostname is assigned
> - Domain is resolvable to the NLB endpoint
> - Endpoint is accessible from your network
> - SSL certificate is properly configured
>
> Once verified, proceed with the next registration commands as provided in the TIBCO® Control Plane.

#### Deploy with Application Load Balancer (ALB)

When using Data Plane deployment with ALB, you need to create an ALB Ingress resource and deploy the `dp-configure-namespace` chart.

> [!NOTE]
> **Timing**: The ALB Ingress resource should ideally be created **before** running the `dp-configure-namespace` installation command. However, you can also create it after the installation. Note that connectivity will not be established until the ALB is provisioned and healthy.

**Follow these steps:**

**Step 1: Create Data Plane Namespace**

Execute the namespace creation commands provided by the TIBCO® Control Plane.

**Step 2: Create ALB Ingress Resource (Recommended - Do this first)**

Create the ALB Ingress to expose your Data Plane. You'll need the registration URL from TIBCO® Control Plane.

1. **Use the registration URL from TIBCO® Control Plane**

   During Data Plane registration, Control Plane provides you with a registration URL.
   
   Example: `https://dataplane-1.aws.example.com`
   
   Break it down into:
   - `<PREFIX>` = `dataplane-1` (the subdomain/service prefix)
   - `<DOMAIN>` = `aws.example.com` (the base domain)

2. **Replace the placeholders in the template below:**
   - `<DP_NAME>` - Your Data Plane name (e.g., dp1, ohc-dp)
   - `<DP_NAMESPACE>` - Kubernetes namespace where HAProxy is deployed
   - `<DOMAIN>` - The base domain from your registration URL
   - `<PREFIX>` - The prefix/subdomain from your registration URL
   - `<ACM_CERTIFICATE_ARN>` - Your AWS Certificate Manager certificate ARN

3. **Apply the Ingress resource:**

```bash
# Set your variables
export DP_NAME="dp1"
export DP_NAMESPACE="haproxy"
export PREFIX="dataplane-1"
export DOMAIN="aws.example.com"
export ACM_CERTIFICATE_ARN="arn:aws:acm:us-west-2:123456789012:certificate/12345678-1234-1234-1234-123456789012"

# Apply the Ingress
kubectl apply -f - <<EOF
kind: Ingress
apiVersion: networking.k8s.io/v1
metadata:
  name: ${DP_NAME}-ingress
  namespace: ${DP_NAMESPACE}
  annotations:
    alb.ingress.kubernetes.io/group.name: "${DOMAIN}"
    external-dns.alpha.kubernetes.io/hostname: "*.${DOMAIN}"
    alb.ingress.kubernetes.io/backend-protocol: HTTP
    alb.ingress.kubernetes.io/certificate-arn: "${ACM_CERTIFICATE_ARN}"
    alb.ingress.kubernetes.io/healthcheck-path: /healthz
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS13-1-2-2021-06
    alb.ingress.kubernetes.io/success-codes: 200-499
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
    - host: "${PREFIX}.${DOMAIN}"
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: cpdpproxy
                port:
                  number: 80
EOF
```

4. **Verify ALB Ingress Creation**

After applying, check the Ingress status:

```bash
kubectl get ingress -n ${DP_NAMESPACE}
kubectl describe ingress ${DP_NAME}-ingress -n ${DP_NAMESPACE}
```

The ALB hostname will appear in the Ingress status after provisioning (typically 2-3 minutes).

```bash
# Get ALB endpoint
export DP_ALB_ENDPOINT=$(kubectl get ingress ${DP_NAME}-ingress -n ${DP_NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "ALB Endpoint: ${DP_ALB_ENDPOINT}"

# Verify DNS and connectivity
nslookup ${PREFIX}.${DOMAIN}
curl -k https://${PREFIX}.${DOMAIN}

# Get ALB IP addresses (needed for Control Plane dpEgress policy)
nslookup ${DP_ALB_ENDPOINT}
```

> [!IMPORTANT]
> **Verification checklist:**
> - Ingress resource is created successfully
> - ALB is provisioned and healthy
> - Domain is resolvable to the ALB endpoint
> - Endpoint is accessible from your network
> - SSL certificate is properly configured

**Step 3: Deploy dp-configure-namespace**

Use the base helm install command of `dp-configure-namespace` chart provided by TIBCO® Control Plane without any additional NLB-specific parameters.

> [!NOTE]
> After deployment, proceed with the next commands as provided in the TIBCO® Control Plane.

#### Control Tower Data Plane Deployment

When deploying Control Tower Data Plane on MicroK8s with no hybrid connectivity, the cluster creation steps are different. Follow the cluster creation steps from the [Control Tower Data Plane documentation](../microk8s/bare-metal-data-plane/README.md).

**Follow these steps:**

**Step 1: Configure LoadBalancer Service (for HaProxy Chart)**

Add this parameter to the helm install command of `dp-configure-namespace` chart provided by TIBCO® Control Plane:

```bash
--set haproxy.controller.service.type=LoadBalancer
```

**Example:**
```bash
# Note: Below is just a sample command. Please replace the values with your actual values.
helm upgrade --install -n haproxy dp-configure-namespace tibco-platform-public/dp-configure-namespace \
  --version 1.15.0 \
  --create-namespace \
  --set haproxy.controller.service.type=LoadBalancer
```

This will expose the Data Plane services using the LoadBalancer type on your MicroK8s cluster.

**Step 2: Register Data Plane URL**

During Data Plane registration in TIBCO® Control Plane, enter the Data Plane URL using either:
- The private IP address of the machine where Control Tower Data Plane is deployed
- The hostname/FQDN of the machine

**Example:**
```
http://10.0.1.100
# OR
http://dataplane-vm.internal.domain
```

Once you've entered the URL, proceed with the Data Plane registration by following the commands displayed in the TIBCO® Control Plane.

**For detailed information on any step, please refer to the [main Data Plane workshop documentation](../eks/data-plane/README.md).**